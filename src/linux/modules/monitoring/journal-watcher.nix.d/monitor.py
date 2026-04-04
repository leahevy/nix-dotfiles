#!/usr/bin/env python3
import json
import os
import re
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, TypedDict


class GroupEntry(TypedDict):
    string: str
    mapping: Optional[Dict[str, Any]]
    pattern_type: Optional[str]
    pattern: Optional[Dict[str, Any]]


@dataclass
class PatternMatch:
    mapping: Optional[Dict[str, Any]] = None
    channels: Optional[Dict[str, Any]] = None
    pattern_id: Optional[str] = None


STATS_INTERVAL = 10 * 60


class Stats:
    def __init__(self) -> None:
        self.total = 0
        self.ignored = 0
        self.highlighted = 0
        self.user_notify = 0
        self.pushover = 0
        self.rate_limited = 0
        self.last_log_time = time.time()

    def maybe_log(self, cfg: Dict[str, Any]) -> None:
        if not cfg.get("stats_enabled", True):
            self.last_log_time = time.time()
            return
        now = time.time()
        if now - self.last_log_time < STATS_INTERVAL:
            return
        elapsed = int(now - self.last_log_time)
        pct_ignored = int(self.ignored / self.total * 100) if self.total else 0
        parts = [
            f"Stats (last {elapsed}s):",
            f"total={self.total}",
            f"ignored={self.ignored} ({pct_ignored}%)",
            f"sent_user={self.user_notify}",
        ]
        if cfg["pushover_enabled"]:
            parts.append(f"pushover={self.pushover}")
        if self.highlighted:
            parts.append(f"highlighted={self.highlighted}")
        if self.rate_limited:
            parts.append(f"rate_limited={self.rate_limited}")
        print(" ".join(parts), flush=True)
        self.total = 0
        self.ignored = 0
        self.highlighted = 0
        self.user_notify = 0
        self.pushover = 0
        self.rate_limited = 0
        self.last_log_time = now


SERVICE_EXTRACT_RE = re.compile(
    r"^([a-zA-Z0-9_-]+\."
    r"(service|timer|socket|target|mount|path|slice|scope|device|swap))"
    r":(.*)$"
)


def compute_pattern_hash(pat: Dict[str, Any]) -> str:
    fields = ["service", "tag", "string", "user", "kernel", "unitless", "all"]
    parts = []
    for field in fields:
        value = pat.get(field)
        if value:
            parts.append(f"{field}={value}")
    key = "|".join(parts) if parts else "empty"
    return sha256(key.encode()).hexdigest()[:16]


class PatternMatcher:
    def __init__(self, patterns: List[Dict[str, Any]], main_user_uid: int):
        self.main_user_uid = main_user_uid
        self.user_unit = f"user@{main_user_uid}.service"

        self.service_only_re = None
        self.tag_only_re = None
        self.string_only_re = None
        self.kernel_string_only_re = None
        self.unitless_string_only_re = None
        self.user_string_only_re = None

        self.compound: List[Dict[str, Any]] = []
        self.grouped: List[Dict[str, Any]] = []

        service_only = []
        tag_only = []
        string_only = []
        kernel_string_only = []
        unitless_string_only = []
        user_string_only = []
        grouped_collect: Dict[Tuple, List[GroupEntry]] = {}

        for pat in patterns:
            service = pat.get("service")
            tag = pat.get("tag")
            string = pat.get("string")
            is_user = pat.get("user", False)
            is_kernel = pat.get("kernel", False)
            is_unitless = pat.get("unitless", False)

            has_service = service is not None
            has_tag = tag is not None
            has_string = string is not None
            field_count = sum([has_service, has_tag, has_string])

            if field_count == 0:
                continue

            if field_count >= 2 and has_string and string is not None:
                if pat.get("channels") is not None:
                    self._add_compound(pat)
                    continue
                key = (
                    service or "",
                    tag or "",
                    is_user,
                    is_kernel,
                    is_unitless,
                )
                if key not in grouped_collect:
                    grouped_collect[key] = []
                grouped_collect[key].append(
                    {
                        "string": string,
                        "mapping": pat.get("mapping"),
                        "pattern_type": pat.get("pattern_type"),
                        "pattern": pat,
                    }
                )
                continue

            if pat.get("pattern_type") == "highlight" and pat.get("mapping"):
                self._add_compound(pat)
                continue

            if field_count == 1 and not is_user:
                if (
                    has_service
                    and not is_kernel
                    and not is_unitless
                    and service is not None
                ):
                    service_only.append(re.escape(service))
                elif has_tag and not is_kernel and not is_unitless and tag is not None:
                    tag_only.append(re.escape(tag))
                elif has_string:
                    if is_kernel:
                        kernel_string_only.append(string)
                    elif is_unitless:
                        unitless_string_only.append(string)
                    else:
                        string_only.append(string)
                else:
                    self._add_compound(pat)
            elif field_count == 1 and is_user and has_string and not is_unitless:
                user_string_only.append(string)
            else:
                self._add_compound(pat)

        if service_only:
            self.service_only_re = re.compile("|".join(f"({p})" for p in service_only))
        if tag_only:
            self.tag_only_re = re.compile("|".join(f"({p})" for p in tag_only))
        if string_only:
            self.string_only_re = re.compile("|".join(f"({p})" for p in string_only))
        if kernel_string_only:
            self.kernel_string_only_re = re.compile(
                "|".join(f"({p})" for p in kernel_string_only)
            )
        if unitless_string_only:
            self.unitless_string_only_re = re.compile(
                "|".join(f"({p})" for p in unitless_string_only)
            )
        if user_string_only:
            self.user_string_only_re = re.compile(
                "|".join(f"({p})" for p in user_string_only)
            )

        for key, entries in grouped_collect.items():
            service_val, tag_val, is_user, is_kernel, is_unitless = key
            has_labels = any(
                e.get("pattern_type") == "highlight" and e.get("mapping")
                for e in entries
            )
            if has_labels:
                parts = []
                labels = []
                for i, e in enumerate(entries):
                    parts.append(f"(?P<g{len(self.grouped)}_{i}>{e['string']})")
                    pattern_hash = None
                    pattern = e.get("pattern")
                    if e.get("pattern_type") == "highlight" and pattern is not None:
                        pattern_hash = compute_pattern_hash(pattern)
                    labels.append(
                        PatternMatch(mapping=e.get("mapping"), pattern_id=pattern_hash)
                    )
                string_re = re.compile("|".join(parts))
            else:
                string_re = re.compile("|".join(f"({e['string']})" for e in entries))
                labels = None
            entry: Dict[str, Any] = {
                "user": is_user,
                "kernel": is_kernel,
                "unitless": is_unitless,
                "string_re": string_re,
                "labels": labels,
            }
            if service_val:
                entry["service"] = re.compile(re.escape(service_val))
            if tag_val:
                entry["tag"] = re.compile(re.escape(tag_val))
            self.grouped.append(entry)

    def _add_compound(self, pat: Dict[str, Any]):
        compiled = {
            "user": pat.get("user", False),
            "kernel": pat.get("kernel", False),
            "unitless": pat.get("unitless", False),
            "mapping": pat.get("mapping"),
            "channels": pat.get("channels"),
        }
        if pat.get("pattern_type") == "highlight":
            compiled["pattern_hash"] = compute_pattern_hash(pat)
        if pat.get("service"):
            compiled["service"] = re.compile(re.escape(pat["service"]))
        if pat.get("tag"):
            compiled["tag"] = re.compile(re.escape(pat["tag"]))
        if pat.get("string"):
            compiled["string"] = re.compile(pat["string"])
        self.compound.append(compiled)

    def _extract_inner_service(self, message: str) -> Optional[str]:
        m = SERVICE_EXTRACT_RE.match(message)
        if m:
            return m.group(1)
        return None

    def _match_impl(
        self, unit: str, tag: str, message: str, transport: str
    ) -> Optional[PatternMatch]:
        is_kernel = transport == "kernel"
        has_unit = bool(unit)
        is_user_unit = unit == self.user_unit

        inner_service = None
        if is_user_unit and message:
            inner_service = self._extract_inner_service(message)

        if has_unit and not is_kernel:
            if self.service_only_re and unit and self.service_only_re.search(unit):
                return PatternMatch()

        if has_unit and not is_kernel and not is_user_unit:
            if self.tag_only_re and tag and self.tag_only_re.search(tag):
                return PatternMatch()

        if has_unit and not is_kernel and not is_user_unit:
            if self.string_only_re and message and self.string_only_re.search(message):
                return PatternMatch()

        if is_kernel:
            if (
                self.kernel_string_only_re
                and message
                and self.kernel_string_only_re.search(message)
            ):
                return PatternMatch()

        if not has_unit and not is_kernel:
            if (
                self.unitless_string_only_re
                and message
                and self.unitless_string_only_re.search(message)
            ):
                return PatternMatch()

        if is_user_unit:
            if (
                self.user_string_only_re
                and message
                and self.user_string_only_re.search(message)
            ):
                return PatternMatch()

        for grp in self.grouped:
            grp_kernel = grp["kernel"]
            grp_unitless = grp["unitless"]
            grp_user = grp["user"]

            if grp_kernel and not is_kernel:
                continue
            if not grp_kernel and is_kernel:
                continue
            if grp_unitless:
                if grp_user:
                    if not is_user_unit or inner_service is not None:
                        continue
                else:
                    if has_unit or is_kernel:
                        continue
            if grp_user and not grp_unitless and not is_user_unit:
                continue
            if not grp_kernel and not grp_unitless and not grp_user and not has_unit:
                continue

            all_match = True
            if "service" in grp:
                if grp_user:
                    if not (inner_service and grp["service"].search(inner_service)):
                        all_match = False
                else:
                    if not (unit and grp["service"].search(unit)):
                        all_match = False
            if "tag" in grp:
                if not (tag and grp["tag"].search(tag)):
                    all_match = False
            if all_match and message:
                m = grp["string_re"].search(message)
                if m:
                    labels = grp["labels"]
                    if labels is None:
                        return PatternMatch()
                    idx = int(m.lastgroup.split("_", 1)[1])
                    return labels[idx]

        for pat in self.compound:
            pat_kernel = pat["kernel"]
            pat_unitless = pat["unitless"]
            pat_user = pat["user"]

            if pat_kernel and not is_kernel:
                continue
            if not pat_kernel and is_kernel:
                continue
            if pat_unitless:
                if pat_user:
                    if not is_user_unit or inner_service is not None:
                        continue
                else:
                    if has_unit or is_kernel:
                        continue
            if pat_user and not pat_unitless and not is_user_unit:
                continue
            if not pat_kernel and not pat_unitless and not pat_user and not has_unit:
                continue

            all_match = True
            if "service" in pat:
                if pat_user:
                    if not (inner_service and pat["service"].search(inner_service)):
                        all_match = False
                else:
                    if not (unit and pat["service"].search(unit)):
                        all_match = False
            if "tag" in pat:
                if not (tag and pat["tag"].search(tag)):
                    all_match = False
            if "string" in pat:
                if not (message and pat["string"].search(message)):
                    all_match = False
            if all_match:
                return PatternMatch(
                    mapping=pat.get("mapping"),
                    channels=pat.get("channels"),
                    pattern_id=pat.get("pattern_hash"),
                )

        return None

    def matches(self, unit: str, tag: str, message: str, transport: str) -> bool:
        return self._match_impl(unit, tag, message, transport) is not None

    def match_highlight(
        self, unit: str, tag: str, message: str, transport: str
    ) -> Optional[PatternMatch]:
        return self._match_impl(unit, tag, message, transport)


def tag_to_title(tag: str) -> str:
    parts = re.split(r"[-_]", tag)
    return " ".join(p if p.isupper() else p.capitalize() for p in parts if p)


def entry_ts(json_data: Dict[str, Any]) -> str:
    try:
        return time.strftime(
            "%b %d %H:%M:%S",
            time.localtime(int(json_data["__REALTIME_TIMESTAMP"]) / 1_000_000),
        )
    except (KeyError, ValueError):
        return "??:??:??"


def to_string(value, default=""):
    if isinstance(value, list):
        if not value:
            return default
        if all(isinstance(x, int) and 0 <= x <= 255 for x in value):
            try:
                return bytes(value).decode("utf-8", errors="replace")
            except Exception:
                return str(value[0])
        else:
            return str(value[0])
    elif value is None:
        return default
    else:
        return str(value)


def setup_directories(cfg: Dict[str, Any]):
    try:
        os.makedirs(cfg["state_dir"], exist_ok=True)
        os.makedirs(cfg["rate_limit_state_dir"], exist_ok=True)
    except (OSError, PermissionError) as e:
        print(f"Failed to create directories: {e}", file=sys.stderr, flush=True)
        sys.exit(1)


def cleanup_old_rate_limits(cfg: Dict[str, Any]):
    current_time = int(time.time())
    cleaned_up = False
    rate_limit_path = Path(cfg["rate_limit_state_dir"])
    if not rate_limit_path.exists():
        return
    for file_path in rate_limit_path.iterdir():
        if file_path.is_file():
            try:
                stored_data = file_path.read_text().strip()
                if ":" in stored_data:
                    _, stored_time_str = stored_data.split(":", 1)
                    stored_time = int(stored_time_str)
                    if current_time - stored_time > (2 * 60 * 60):
                        file_path.unlink()
                        cleaned_up = True
            except (ValueError, IOError):
                continue
    if cleaned_up:
        print("Cleaned up old rate limit files.", flush=True)


def check_hourly_rate_limit(
    cfg: Dict[str, Any], filename: str, rate_limit: int
) -> bool:
    rate_limit_file = Path(cfg["rate_limit_state_dir"]) / filename
    current_time = int(time.time())
    current_hour = current_time // 3600
    if rate_limit_file.exists():
        try:
            stored_data = rate_limit_file.read_text().strip()
            stored_count_str, stored_time_str = stored_data.split(":", 1)
            stored_count = int(stored_count_str)
            stored_hour = int(stored_time_str) // 3600
            if stored_hour == current_hour:
                if stored_count >= rate_limit:
                    return False
                else:
                    rate_limit_file.write_text(f"{stored_count + 1}:{current_time}")
                    return True
            else:
                rate_limit_file.write_text(f"1:{current_time}")
                return True
        except (ValueError, IOError):
            rate_limit_file.write_text(f"1:{current_time}")
            return True
    else:
        rate_limit_file.write_text(f"1:{current_time}")
        return True


def check_rate_limit(cfg: Dict[str, Any], service_unit: str) -> bool:
    service_file = re.sub(r"[^a-zA-Z0-9_-]", "_", service_unit)
    if not service_file:
        service_file = "unknown"
    rate_limit = (
        cfg["rate_limit_per_hour_unknown"]
        if service_file == "unknown"
        else cfg["rate_limit_per_hour"]
    )
    return check_hourly_rate_limit(cfg, service_file, rate_limit)


def check_highlight_rate_limit(cfg: Dict[str, Any], pattern_hash: str) -> bool:
    rate_limit = cfg.get("highlight_rate_limit_per_hour", cfg["rate_limit_per_hour"])
    return check_hourly_rate_limit(cfg, f"hl_{pattern_hash}", rate_limit)


def check_message_rate_limit(
    cfg: Dict[str, Any], service_unit: str, message: str
) -> bool:
    message_key = f"{service_unit}:{message}"
    message_hash = sha256(message_key.encode()).hexdigest()
    current_time = int(time.time())
    rate_limit_seconds = cfg["message_rate_limit_minutes"] * 60
    message_hashes_path = Path(cfg["message_hashes_file"])
    valid_hashes = []
    if message_hashes_path.exists():
        try:
            for line in message_hashes_path.read_text().splitlines():
                if ":" in line:
                    stored_hash, stored_time_str = line.split(":", 1)
                    try:
                        stored_time = int(stored_time_str)
                        if current_time - stored_time < rate_limit_seconds:
                            valid_hashes.append(line)
                            if stored_hash == message_hash:
                                return False
                        else:
                            print(
                                f"Message rate limit expired for message: ({service_unit}) {message}",
                                flush=True,
                            )
                    except ValueError:
                        continue
        except IOError:
            pass
    valid_hashes.append(f"{message_hash}:{current_time}")
    try:
        message_hashes_path.write_text("\n".join(valid_hashes) + "\n")
    except IOError:
        pass
    return True


def build_message_context(
    json_data: Dict[str, Any], main_user_uid: int
) -> Optional[Dict[str, Any]]:
    is_inner_user_service = False
    priority = to_string(json_data.get("PRIORITY", "6"), "6")
    message = to_string(json_data.get("MESSAGE"))
    unit = to_string(json_data.get("_SYSTEMD_UNIT", "unknown"), "unknown")
    tag = to_string(json_data.get("SYSLOG_IDENTIFIER", "system"), "system")

    is_user_unit = unit == f"user@{main_user_uid}.service"
    is_unknown_unit = unit == "unknown"

    if is_user_unit or is_unknown_unit:
        match = SERVICE_EXTRACT_RE.match(message)
        if match:
            is_inner_user_service = True
            unit = match.group(1)
            message = match.group(3).strip()

    if not message:
        return None

    transport = to_string(json_data.get("_TRANSPORT"))
    is_kernel = transport == "kernel"
    has_no_unit = is_unknown_unit and not is_inner_user_service

    pattern_info: Dict[str, Any] = {
        "string": message,
        "service": unit,
        "tag": tag,
        "priority": int(priority),
    }
    if is_inner_user_service:
        pattern_info["user"] = True
    if is_kernel:
        pattern_info["kernel"] = True
    elif has_no_unit:
        pattern_info["unitless"] = True
    elif is_user_unit and not is_inner_user_service:
        pattern_info["service"] = None
        pattern_info["user"] = True
        pattern_info["unitless"] = True

    return {
        "pattern_info": pattern_info,
        "message": message,
        "unit": unit,
        "tag": tag,
        "priority": int(priority),
        "is_inner_user_service": is_inner_user_service,
        "is_user_unit": is_user_unit,
        "is_kernel": is_kernel,
        "has_no_unit": has_no_unit,
    }


def filter_message(
    json_data: Dict[str, Any],
    ignore_matcher: PatternMatcher,
    highlight_matcher: PatternMatcher,
) -> Tuple[bool, bool, Optional[PatternMatch]]:
    unit = to_string(json_data.get("_SYSTEMD_UNIT"))
    tag = to_string(json_data.get("SYSLOG_IDENTIFIER"))
    message = to_string(json_data.get("MESSAGE"))
    transport = to_string(json_data.get("_TRANSPORT"))
    priority = int(to_string(json_data.get("PRIORITY", "6"), "6"))

    ignored = ignore_matcher.matches(unit, tag, message, transport)
    highlight_info = highlight_matcher.match_highlight(unit, tag, message, transport)
    highlighted = highlight_info is not None

    if highlighted:
        ignored = False

    if not ignored and priority > 4 and not highlighted:
        ignored = True

    return ignored, highlighted, highlight_info


def send_user_notify(
    cfg: Dict[str, Any],
    title: str,
    body: str,
    icon: str,
    priority: str = "user.warning",
):
    payload = json.dumps({"title": title, "body": body, "icon": icon})
    subprocess.run(
        [
            cfg["logger_bin"],
            "-p",
            priority,
            "-t",
            "nx-user-notify",
            f"JSON-DATA::{payload}",
        ],
        check=False,
        timeout=30,
    )


def process_message(
    cfg: Dict[str, Any],
    json_data: Dict[str, Any],
    highlighted: bool,
    highlight_info: Optional[PatternMatch],
    stats: Stats,
):
    try:
        ctx = build_message_context(json_data, cfg["main_user_uid"])
        if ctx is None:
            return

        message = ctx["message"]
        unit = ctx["unit"]
        tag = ctx["tag"]
        priority = ctx["priority"]
        is_inner_user_service = ctx["is_inner_user_service"]
        is_user_unit = ctx["is_user_unit"]
        is_kernel = ctx["is_kernel"]
        has_no_unit = ctx["has_no_unit"]
        pattern_info = ctx["pattern_info"]
        ts_prefix = f"[{entry_ts(json_data)}] " if cfg["dev_enabled"] else ""

        cleanup_old_rate_limits(cfg)

        if not check_message_rate_limit(cfg, unit, message):
            print(
                f"{ts_prefix}Ignore notification <rate limited> ({tag}/{unit}): {message}",
                flush=True,
            )
            stats.rate_limited += 1
            return

        if highlighted and highlight_info and highlight_info.pattern_id:
            if not check_highlight_rate_limit(cfg, highlight_info.pattern_id):
                print(
                    f"{ts_prefix}Ignore notification <highlight pattern rate limited> ({tag}/{unit}): {message}",
                    flush=True,
                )
                stats.rate_limited += 1
                return

        hl_marker = " [highlighted]" if highlighted else ""
        print(
            f"{ts_prefix}Send notification{hl_marker} pattern: {json.dumps(pattern_info)}",
            flush=True,
        )

        priority_map = {
            0: "emerg",
            1: "emerg",
            2: "emerg",
            3: "failed",
            4: "warn",
        }
        notify_type = priority_map.get(priority, "info")

        priority_titles = {
            "emerg": "Emergency",
            "failed": "Failed",
            "warn": "Warning",
            "info": "Info",
        }

        icon_map_system = cfg["icon_map_system"]
        icon_map_user = cfg["icon_map_user"]
        icon = (
            icon_map_user.get(notify_type, icon_map_user["info"])
            if is_user_unit
            else icon_map_system.get(notify_type, icon_map_system["info"])
        )
        priority_title = priority_titles.get(notify_type, "Info")

        generic_tags = {"system", cfg.get("main_user_username", "")}
        display_tag = tag if tag and tag not in generic_tags else None

        effective_mapping: Dict[str, Any] = {}
        tag_mapping = cfg.get("tag_mappings", {}).get(tag)
        if tag_mapping:
            effective_mapping.update(
                {k: v for k, v in tag_mapping.items() if v is not None}
            )
        if highlight_info and highlight_info.mapping:
            effective_mapping.update(
                {k: v for k, v in highlight_info.mapping.items() if v is not None}
            )

        hl_title = effective_mapping.get("title")
        if hl_title is not None:
            suffix = hl_title
        elif is_inner_user_service or (
            unit != "unknown" and not is_user_unit and not is_kernel
        ):
            suffix = unit
        elif display_tag:
            suffix = tag_to_title(display_tag)
        else:
            suffix = "Journal Message"

        hl_label = effective_mapping.get("label")
        if hl_label is not None:
            bracket = f"[{hl_label}]" if hl_label else ""
        elif is_kernel:
            bracket = "[Kernel]"
        elif is_user_unit or is_inner_user_service:
            bracket = "[User]"
        else:
            bracket = "[NixOS]"

        if effective_mapping:
            type_icon_key = {
                "emerg": "emergIcon",
                "failed": "failedIcon",
                "warn": "warnIcon",
            }.get(notify_type, "infoIcon")
            override_icon = effective_mapping.get(type_icon_key)
            if override_icon is None:
                override_icon = effective_mapping.get("icon")
            if override_icon is not None:
                icon = override_icon

        bracket_label = bracket.strip("[]") if bracket else ""
        if bracket and bracket_label.lower() == suffix.lower():
            title = suffix
        else:
            title = f"{bracket} {suffix}" if bracket else suffix

        title_text_pushover = title
        tag_suffix = tag_to_title(display_tag) if display_tag else None
        message_text_pushover = (
            f"{message} ({tag_suffix})"
            if (display_tag and suffix != tag_suffix)
            else message
        )
        message_text_user = (
            f"{message} <b>({tag_suffix})</b>"
            if (display_tag and suffix != tag_suffix)
            else message
        )

        if effective_mapping.get("message") is not None:
            message_text_pushover = effective_mapping["message"]
            message_text_user = effective_mapping["message"]

        hl_channels = {}
        if highlighted and highlight_info and highlight_info.channels:
            hl_channels = highlight_info.channels

        if cfg["user_notify_enabled"] and not cfg["debug_enabled"]:
            if hl_channels.get("user") is not False:
                try:
                    send_user_notify(cfg, title, message_text_user, icon)
                    stats.user_notify += 1
                except (subprocess.TimeoutExpired, OSError) as e:
                    print(
                        f"Failed to send user notification: {e}",
                        file=sys.stderr,
                        flush=True,
                    )

        if cfg["pushover_enabled"] and not cfg["debug_enabled"]:
            should_send_pushover = True

            pushover_channel = hl_channels.get("pushover")

            if pushover_channel is False:
                should_send_pushover = False
            elif is_user_unit and cfg["ignore_user_services_for_pushover"]:
                if is_inner_user_service:
                    should_send_pushover = False
                elif pushover_channel is not True:
                    should_send_pushover = False

            if should_send_pushover and (highlighted or check_rate_limit(cfg, unit)):
                pushover_cmd = list(cfg["pushover_cmd"])
                pushover_cmd = [
                    s.format(
                        title_text_pushover=title_text_pushover,
                        message_text_pushover=message_text_pushover,
                        notify_type=notify_type,
                    )
                    for s in pushover_cmd
                ]
                try:
                    result = subprocess.run(pushover_cmd, check=False, timeout=30)
                    if result.returncode == 0:
                        stats.pushover += 1
                    else:
                        err_msg = f"pushover-send exited with code {result.returncode}"
                        print(
                            f"Failed to send pushover notification: {err_msg}",
                            file=sys.stderr,
                            flush=True,
                        )
                        if cfg["user_notify_enabled"]:
                            send_user_notify(
                                cfg,
                                "Pushover Error",
                                err_msg,
                                "dialog-error",
                                "user.err",
                            )
                except (subprocess.TimeoutExpired, OSError) as e:
                    print(
                        f"Failed to send pushover notification: {e}",
                        file=sys.stderr,
                        flush=True,
                    )
                    if cfg["user_notify_enabled"]:
                        send_user_notify(
                            cfg, "Pushover Error", str(e), "dialog-error", "user.err"
                        )
    except Exception as e:
        print(f"Error processing message: {e}", file=sys.stderr, flush=True)


def main():
    if len(sys.argv) != 2:
        print("Usage: monitor.py <config.json>", file=sys.stderr, flush=True)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        cfg = json.load(f)

    if cfg["dev_enabled"]:
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)

    setup_directories(cfg)

    ignore_matcher = PatternMatcher(cfg["ignore_patterns"], cfg["main_user_uid"])
    highlight_matcher = PatternMatcher(cfg["highlight_patterns"], cfg["main_user_uid"])
    stats = Stats()

    cmd = [
        cfg["journalctl_bin"],
        "-f",
        "-p",
        "debug",
        "--output=json",
        f"--cursor-file={cfg['cursor_file']}",
    ]

    parts = [
        "Starting journal watcher",
        f"ignore_patterns={len(cfg['ignore_patterns'])}",
        f"highlight_patterns={len(cfg['highlight_patterns'])}",
        f"debug={cfg['debug_enabled']}",
        f"dev={cfg['dev_enabled']}",
        f"stats={cfg['stats_enabled']}",
        f"user_notify={cfg['user_notify_enabled']}",
        f"pushover={cfg['pushover_enabled']}",
        f"rate_limit={cfg['rate_limit_per_hour']}/h",
        f"dedup={cfg['message_rate_limit_minutes']}min",
    ]
    if not cfg["dev_enabled"]:
        print(" ".join(parts), flush=True)
    try:
        with subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1
        ) as proc:
            for line in proc.stdout:
                line = line.strip()
                if line:
                    try:
                        json_data = json.loads(line)
                        ignored, highlighted, highlight_info = filter_message(
                            json_data, ignore_matcher, highlight_matcher
                        )
                        stats.total += 1
                        if ignored:
                            stats.ignored += 1
                            if cfg["dev_enabled"]:
                                ctx = build_message_context(
                                    json_data, cfg["main_user_uid"]
                                )
                                if ctx and ctx["unit"] != "nx-journal-watcher.service":
                                    print(
                                        f"[{entry_ts(json_data)}] Ignore pattern: {json.dumps(ctx['pattern_info'])}",
                                        flush=True,
                                    )
                        else:
                            if highlighted:
                                stats.highlighted += 1
                            process_message(
                                cfg, json_data, highlighted, highlight_info, stats
                            )
                        stats.maybe_log(cfg)
                    except json.JSONDecodeError:
                        continue
    except KeyboardInterrupt:
        print("Journal watcher stopped.", flush=True)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr, flush=True)
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass
