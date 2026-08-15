import contextlib
import hashlib
import hmac
import json
import os
import random
import re
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from queue import Empty, Full, Queue

import yaml

CONNECT_RETRY_SECONDS = 60
CONNECT_RETRY_DELAY = 1.0
BOOTSTRAP_RETRY_SECONDS = 180
BOOTSTRAP_RETRY_DELAY = 10.0
GROUP_UPDATE_ATTEMPTS = 3
GROUP_UPDATE_RETRY_DELAY = 5.0
HA_AGENT_ERROR_SPEECH = "Error talking to OpenAI"
HA_AGENT_ERROR_RETRY_DELAYS = (3.0, 10.0)
TOOL_CALL_ARTIFACT_PATTERN = re.compile(
    r"multi_tool_use\.parallel|\bfunctions\.[A-Za-z_]\w*\s*\("
)
RECIPIENTS_RECHECK_SECONDS = 60.0
REJECT_LOG_INTERVAL_SECONDS = 60.0
MAX_MESSAGE_BYTES = 2048
MESSAGE_ELLIPSIS = "..."
MARKDOWN_FENCE = "```"
MARKDOWN_ESCAPABLE = "*_~`|#\\"
MARKDOWN_MARKERS = (
    ("**", "BOLD", False),
    ("__", "BOLD", False),
    ("~~", "STRIKETHROUGH", False),
    ("||", "SPOILER", False),
    ("`", "MONOSPACE", True),
    ("*", "ITALIC", False),
    ("_", "ITALIC", False),
)
JOURNAL_ERROR_PREFIX = "<3>"
RESPONSE_SETTLE_SECONDS = 1.0
SEND_PACING_SECONDS = 1.0
SEND_BURST_WINDOW_SECONDS = 60.0
SEND_DEFER_MAX_SECONDS = 3600.0
DEFER_POLL_SECONDS = 60.0
CLOCK_SKEW_TOLERANCE_SECONDS = 300
MAX_REQUEST_BYTES = 65536
STATE_DIR_MODE = 0o700
STATE_FILE_MODE = 0o600
HANDLED_HISTORY_LIMIT = 500
CONVERSATION_HISTORY_LIMIT = 200
QUOTE_TEXT_LIMIT = 300
QUOTE_CONTEXT_LIMIT = 500
GROUP_SEQUENCE_KEY = "_nxGroupSequence"
RECAP_BUDGET_WEIGHT = 0.5
SENDER_BUDGET_WINDOW_SECONDS = 86400.0
DAILY_TRANSCRIPT_LIMIT = 200
HOOK_POLL_SECONDS = 30.0
HOOK_MIN_SLEEP_SECONDS = 0.5
SECONDS_PER_DAY = 86400
HOOK_BLOCK_POLICY = {"exclusion": "skip", "prerequisite": "wait"}
TYPING_REFRESH_SECONDS = 5
DISCOVERABLE_BY_NUMBER = False
GROUP_PARTICIPANT_FIELDS = ("members", "pendingMembers", "requestingMembers")
GROUP_BANNED_FIELDS = ("banned",)
GROUP_ADMIN_FIELDS = ("admins",)
ONLY_ADMINS = "only-admins"
GROUP_LINK_DISABLED = "disabled"
SEND_RESULT_SUCCESS = "SUCCESS"
CONTACT_KEYS = ("name", "number", "admin")
CONTACT_NAME_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9._-]*$")
E164_DIGITS = "0123456789"
E164_MIN_DIGITS = 7
E164_MAX_DIGITS = 15
EMOJI_VARIATION_SELECTORS = ("\ufe0e", "\ufe0f")
EMOJI_SKIN_TONE_FIRST = "\U0001f3fb"
EMOJI_SKIN_TONE_LAST = "\U0001f3ff"
EMOJI_ZWJ = "\u200d"


REQUIRED_CONFIG_KEYS = (
    "socket_path",
    "account_file",
    "signal_cli_data_dir",
    "group_id_file",
    "recipients_file",
    "profile_state_file",
    "handled_file",
    "send_state_file",
    "sender_budget_file",
    "main_group_name",
    "profile_given_name",
    "profile_about",
    "profile_avatar",
    "group_avatar",
    "ha_url",
    "ha_language",
    "ha_agent_id",
    "ha_timeout_seconds",
    "ha_token_file",
    "api_token_file",
    "contacts_file",
    "api_port",
    "queue_max_depth",
    "max_sends_per_hour",
    "max_sends_per_minute",
    "max_budget_per_sender_per_day",
    "budget_input_chars",
    "budget_output_chars",
    "inbound_max_age_seconds",
    "max_split_messages",
    "bold_title",
    "markdown",
    "quote_replies",
    "typing_indicator_delay_seconds",
    "group_filter",
    "conversation_follow_up_seconds",
    "night_follow_up_seconds",
    "night_start_hour",
    "night_end_hour",
    "ha_session_seconds",
    "context_max_messages",
    "context_max_chars",
    "additional_hook_sends_per_day",
    "min_seconds_between_hooks",
    "min_seconds_since_bot_message",
    "min_seconds_since_user_message",
    "hooks_instruction",
    "hooks_prompt_template",
    "hooks_transcript_separator",
    "hooks_transcript_separator_template",
    "hooks_context_max_chars",
    "hooks_block_min_chars",
    "daily_transcript_limit",
    "hooks",
    "hook_state_file",
    "instruction_template",
    "reactions",
    "transcription",
    "messages",
)

REQUIRED_HOOK_KEYS = (
    "enable",
    "start_time",
    "end_time",
    "probability",
    "min_user_interactions",
    "triggers",
    "context_first_messages",
    "context_recent_messages",
    "on_block",
    "agent_id",
    "min_seconds_since_bot_message",
    "min_seconds_since_user_message",
    "send_errors_into_chat",
    "run_only_if_fired_today",
    "skip_if_fired_today",
)

REQUIRED_TRIGGER_KEYS = (
    "instruction",
    "title",
    "url",
)

HOOK_TIME_PATTERN = re.compile(r"^([01][0-9]|2[0-3]):[0-5][0-9]$")

REQUIRED_REACTION_KEYS = (
    "enable",
    "target_max_age_seconds",
    "target_max_messages",
    "instruction",
    "prompt_template",
    "fallback",
    "emoji",
)

REQUIRED_TRANSCRIPTION_KEYS = (
    "enable",
    "attachments_dir",
    "audio_placeholder",
    "transcribe_command",
    "ffmpeg",
    "timeout_seconds",
    "max_duration_seconds",
    "max_attachment_bytes",
    "failure_message",
    "instruction",
    "prompt_template",
)

REQUIRED_GROUP_FILTER_KEYS = (
    "enable",
    "agent_id",
    "instruction",
    "prompt_template",
    "context_messages",
    "context_template",
    "silent_answers",
    "maybe_answers",
    "maybe_probability",
    "maybe_budget",
    "maybe_budget_seconds",
)

REQUIRED_MESSAGE_KEYS = (
    "ha_unreachable",
    "ha_unexpected_response",
    "ha_agent_failed",
    "ha_tool_call_artifact",
    "status_template",
    "status_budget_entry_template",
    "status_maybe_budget_template",
    "status_maybe_budget_disabled",
    "status_hooks_disabled",
    "status_hooks_template",
    "status_hook_entry_template",
    "status_hook_fired",
    "status_hook_scheduled",
    "status_hook_idle",
    "status_account_ok",
    "status_account_missing",
    "status_ha_reachable",
    "status_ha_unreachable",
    "help_entry_template",
    "help_status_description",
    "help_help_description",
    "quote_context_template",
    "quote_context_bot",
    "quote_context_user",
    "group_speaker_template",
    "context_recap_template",
    "context_recap_entry_template",
    "script_recap_template",
    "budget_exhausted",
)


def load_config(path):
    with open(path) as f:
        cfg = json.load(f)
    if not isinstance(cfg, dict):
        raise SystemExit("signal-bot: the config file is not an object!")
    missing = [key for key in REQUIRED_CONFIG_KEYS if key not in cfg]
    if missing:
        raise SystemExit(
            f"signal-bot: the config file is missing {', '.join(missing)}!"
        )
    messages = cfg["messages"]
    if not isinstance(messages, dict):
        raise SystemExit("signal-bot: the config messages are not an object!")
    missing = [key for key in REQUIRED_MESSAGE_KEYS if key not in messages]
    if missing:
        raise SystemExit(
            f"signal-bot: the config messages are missing {', '.join(missing)}!"
        )
    reactions = cfg["reactions"]
    if not isinstance(reactions, dict):
        raise SystemExit("signal-bot: the config reactions are not an object!")
    missing = [key for key in REQUIRED_REACTION_KEYS if key not in reactions]
    if missing:
        raise SystemExit(
            f"signal-bot: the config reactions are missing {', '.join(missing)}!"
        )
    if not isinstance(reactions["emoji"], dict):
        raise SystemExit("signal-bot: the config reaction emoji are not an object!")
    transcription = cfg["transcription"]
    if not isinstance(transcription, dict):
        raise SystemExit("signal-bot: the config transcription is not an object!")
    missing = [key for key in REQUIRED_TRANSCRIPTION_KEYS if key not in transcription]
    if missing:
        raise SystemExit(
            f"signal-bot: the config transcription is missing {', '.join(missing)}!"
        )
    if transcription["enable"] and not transcription["transcribe_command"]:
        raise SystemExit("signal-bot: the config transcription has no command!")
    group_filter = cfg["group_filter"]
    if not isinstance(group_filter, dict):
        raise SystemExit("signal-bot: the config group filter is not an object!")
    missing = [key for key in REQUIRED_GROUP_FILTER_KEYS if key not in group_filter]
    if missing:
        raise SystemExit(
            f"signal-bot: the config group filter is missing {', '.join(missing)}!"
        )
    if group_filter["enable"] and not group_filter["silent_answers"]:
        raise SystemExit("signal-bot: the config group filter has no silent answers!")
    validate_hooks(cfg["hooks"])
    return cfg


def validate_hooks(hooks):
    if not isinstance(hooks, dict):
        raise SystemExit("signal-bot: the config hooks are not an object!")
    for name, hook in hooks.items():
        if not isinstance(hook, dict):
            raise SystemExit(f"signal-bot: hook {name!r} is not an object!")
        missing = [key for key in REQUIRED_HOOK_KEYS if key not in hook]
        if missing:
            raise SystemExit(
                f"signal-bot: hook {name!r} is missing {', '.join(missing)}!"
            )
        for key in ("start_time", "end_time"):
            if not HOOK_TIME_PATTERN.match(str(hook[key])):
                raise SystemExit(
                    f"signal-bot: hook {name!r} has an invalid {key}, expected HH:MM!"
                )
        triggers = hook["triggers"]
        if not isinstance(triggers, list) or not triggers:
            raise SystemExit(
                f"signal-bot: hook {name!r} must define at least one trigger!"
            )
        for trigger in triggers:
            if not isinstance(trigger, dict):
                raise SystemExit(
                    f"signal-bot: hook {name!r} has a trigger that is not an object!"
                )
            trigger_missing = [
                key for key in REQUIRED_TRIGGER_KEYS if key not in trigger
            ]
            if trigger_missing:
                raise SystemExit(
                    f"signal-bot: hook {name!r} has a trigger missing "
                    f"{', '.join(trigger_missing)}!"
                )
            instruction = trigger["instruction"]
            if not isinstance(instruction, str) or not instruction:
                raise SystemExit(
                    f"signal-bot: hook {name!r} has a trigger without an instruction!"
                )
        for key in ("run_only_if_fired_today", "skip_if_fired_today"):
            deps = hook[key]
            if not isinstance(deps, list) or not all(
                isinstance(dep, str) for dep in deps
            ):
                raise SystemExit(
                    f"signal-bot: hook {name!r} {key} must be a list of hook names!"
                )
            if name in deps:
                raise SystemExit(f"signal-bot: hook {name!r} {key} lists its own name!")
            missing_deps = [dep for dep in deps if dep not in hooks]
            if missing_deps:
                raise SystemExit(
                    f"signal-bot: hook {name!r} {key} references unknown hooks "
                    f"{', '.join(missing_deps)}!"
                )


def message_text(cfg, key):
    return cfg["messages"][key]


def log_error(message):
    print(f"{JOURNAL_ERROR_PREFIX}{message}", file=sys.stderr)


def read_secret(path):
    with open(path) as f:
        return f.read().strip()


def require_secret(path, name):
    try:
        value = read_secret(path)
    except OSError as e:
        raise SystemExit(f"signal-bot: could not read the {name} secret: {e}!")
    if not value:
        raise SystemExit(f"signal-bot: the {name} secret is empty!")
    return value


def normalize_contact_number(value, name):
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        raise SystemExit(
            f"signal-bot: contact {name!r} must give number as a string or an integer!"
        )
    text = str(value).strip()
    if not text.startswith("+"):
        text = f"+{text}"
    digits = text[1:]
    if not digits or any(digit not in E164_DIGITS for digit in digits):
        raise SystemExit(f"signal-bot: contact {name!r} has a non numeric number!")
    if digits.startswith("0"):
        raise SystemExit(
            f"signal-bot: contact {name!r} must use an E.164 country code without a "
            "leading zero!"
        )
    if not E164_MIN_DIGITS <= len(digits) <= E164_MAX_DIGITS:
        raise SystemExit(
            f"signal-bot: contact {name!r} must hold between {E164_MIN_DIGITS} and "
            f"{E164_MAX_DIGITS} digits!"
        )
    return text


def read_contact_name(entry, known_names):
    name = entry.get("name")
    if not isinstance(name, str) or not CONTACT_NAME_PATTERN.match(name):
        raise SystemExit(
            "signal-bot: every contact needs a name starting with a letter and "
            "holding only letters, digits, dots, underscores or hyphens!"
        )
    if name in known_names:
        raise SystemExit(f"signal-bot: contact {name!r} is defined twice!")
    unknown = sorted(set(entry) - set(CONTACT_KEYS))
    if unknown:
        raise SystemExit(
            f"signal-bot: contact {name!r} has unknown keys: {', '.join(unknown)}!"
        )
    return name


def read_contacts(path, account):
    with open(path) as f:
        doc = yaml.safe_load(f)
    if not isinstance(doc, dict):
        raise SystemExit("signal-bot: contacts file is not a mapping!")
    entries = doc.get("contacts")
    if not isinstance(entries, list) or not entries:
        raise SystemExit("signal-bot: contacts must be a non empty list!")

    by_name = {}
    by_number = {}
    admin_numbers = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise SystemExit("signal-bot: every contacts entry must be a mapping!")
        name = read_contact_name(entry, by_name)
        if "number" not in entry:
            raise SystemExit(f"signal-bot: contact {name!r} has no number!")
        number = normalize_contact_number(entry["number"], name)
        if number == account:
            raise SystemExit(
                f"signal-bot: contact {name!r} uses the bot account number!"
            )
        if number in by_number:
            raise SystemExit(
                f"signal-bot: contact {name!r} shares its number with contact "
                f"{by_number[number]!r}!"
            )
        admin = entry.get("admin", False)
        if not isinstance(admin, bool):
            raise SystemExit(f"signal-bot: contact {name!r} has a non boolean admin!")
        by_name[name] = number
        by_number[number] = name
        if admin:
            admin_numbers.add(number)
    return by_name, by_number, admin_numbers


def load_contacts(cfg, account):
    return read_contacts(cfg["contacts_file"], account)


def file_digest(path):
    if not path:
        return ""
    try:
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()
    except OSError as e:
        raise SystemExit(f"signal-bot: could not read the avatar file {path}: {e}!")


def read_json_state(path):
    if not os.path.isfile(path):
        return None
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def fsync_directory(path):
    fd = os.open(path, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def write_state_file(path, content):
    directory = os.path.dirname(path)
    os.makedirs(directory, mode=STATE_DIR_MODE, exist_ok=True)
    tmp_path = f"{path}.tmp"
    fd = os.open(tmp_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, STATE_FILE_MODE)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(tmp_path, STATE_FILE_MODE)
        os.replace(tmp_path, path)
        fsync_directory(directory)
    except BaseException:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


def write_json_state(path, value):
    write_state_file(path, json.dumps(value))


def read_group_id(path):
    if not os.path.isfile(path):
        return None
    try:
        with open(path) as f:
            value = f.read().strip()
    except OSError:
        return None
    return value or None


def write_group_id(path, group_id):
    write_state_file(path, group_id)


def forget_group_id(path):
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass


def connect_with_retry(socket_path):
    deadline = time.monotonic() + CONNECT_RETRY_SECONDS
    while True:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            sock.connect(socket_path)
            return sock
        except OSError as e:
            sock.close()
            if time.monotonic() >= deadline:
                raise SystemExit(
                    "signal-bot: could not connect to the signal-cli socket "
                    f"within {CONNECT_RETRY_SECONDS}s: {e}!"
                )
            time.sleep(CONNECT_RETRY_DELAY)


class RpcError(Exception):
    pass


class GroupMissing(Exception):
    pass


class TransientError(Exception):
    pass


def describe_rpc_error(error):
    if isinstance(error, dict):
        return f"code {error.get('code')} with keys {sorted(error)}"
    return type(error).__name__


def describe_send_failures(result):
    if not isinstance(result, dict):
        return None
    entries = result.get("results")
    if not isinstance(entries, list):
        return None
    counts = {}
    retry_after = None
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        kind = entry.get("type")
        if not isinstance(kind, str) or kind == SEND_RESULT_SUCCESS:
            continue
        counts[kind] = counts.get(kind, 0) + 1
        seconds = entry.get("retryAfterSeconds")
        if isinstance(seconds, (int, float)) and not isinstance(seconds, bool):
            retry_after = seconds if retry_after is None else max(retry_after, seconds)
    if not counts:
        return None
    summary = ", ".join(f"{kind} x{count}" for kind, count in sorted(counts.items()))
    if retry_after is None:
        return summary, None
    return f"{summary}, retry after {int(retry_after)}s", retry_after


def call_with_retry(rpc, method, params):
    for attempt in range(1, GROUP_UPDATE_ATTEMPTS + 1):
        try:
            return rpc.call_checked(method, params)
        except RpcError as e:
            if attempt == GROUP_UPDATE_ATTEMPTS:
                raise
            print(
                f"signal-bot: {method} attempt {attempt} failed, retrying: {e}",
                file=sys.stderr,
            )
            time.sleep(GROUP_UPDATE_RETRY_DELAY)


class SignalRpc:
    def __init__(self, socket_path, account):
        self.account = account
        self.closing = False
        self.sock = connect_with_retry(socket_path)
        self.sockfile = self.sock.makefile("rwb")
        self.write_lock = threading.Lock()
        self.pending_lock = threading.Lock()
        self.pending = {}
        self.next_id = 1
        self.on_receive = None

    def start_reader(self):
        thread = threading.Thread(target=self._read_loop, daemon=True)
        thread.start()

    def close(self):
        self.closing = True
        try:
            self.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.sock.close()

    def _read_loop(self):
        while True:
            try:
                line = self.sockfile.readline()
            except (OSError, ValueError):
                line = b""
            if not line:
                if self.closing:
                    return
                print("signal-bot: RPC socket closed by signal-cli", file=sys.stderr)
                os._exit(1)
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if "id" in msg and msg["id"] is not None:
                with self.pending_lock:
                    waiter = self.pending.pop(msg["id"], None)
                if waiter is not None:
                    waiter["response"] = msg
                    waiter["event"].set()
            elif msg.get("method") == "receive" and self.on_receive is not None:
                self.on_receive(msg.get("params", {}))

    def call_checked(self, method, params=None, timeout=30):
        call_params = {"account": self.account}
        if params:
            call_params.update(params)
        with self.pending_lock:
            req_id = self.next_id
            self.next_id += 1
            event = threading.Event()
            slot = {"event": event, "response": None}
            self.pending[req_id] = slot
        request = {
            "jsonrpc": "2.0",
            "method": method,
            "id": req_id,
            "params": call_params,
        }
        data = (json.dumps(request) + "\n").encode()
        with self.write_lock:
            self.sockfile.write(data)
            self.sockfile.flush()
        if not event.wait(timeout):
            with self.pending_lock:
                waiter = self.pending.pop(req_id, None)
            if waiter is None:
                event.wait(RESPONSE_SETTLE_SECONDS)
        response = slot["response"]
        if response is None:
            raise RpcError(f"{method} timed out after {timeout}s")
        if "error" in response:
            raise RpcError(f"{method} failed: {describe_rpc_error(response['error'])}")
        return response.get("result")


def read_account_path(data_dir, account):
    doc = read_json_state(os.path.join(data_dir, "accounts.json"))
    if not isinstance(doc, dict):
        return None
    entries = doc.get("accounts")
    if not isinstance(entries, list):
        return None
    for entry in entries:
        if not isinstance(entry, dict) or entry.get("number") != account:
            continue
        path = entry.get("path")
        if isinstance(path, str) and path:
            return path
    return None


def required_account_files(cfg, account):
    data_dir = os.path.join(cfg["signal_cli_data_dir"], "data")
    account_path = read_account_path(data_dir, account) or account
    return [
        ("accounts.json", os.path.join(data_dir, "accounts.json")),
        ("account data file", os.path.join(data_dir, account_path)),
        (
            "account database",
            os.path.join(data_dir, f"{account_path}.d", "account.db"),
        ),
    ]


def missing_account_files(cfg, account):
    return [
        label
        for label, path in required_account_files(cfg, account)
        if not os.path.isfile(path)
    ]


def ensure_account_provisioned(cfg, account):
    missing = missing_account_files(cfg, account)
    if not missing:
        return
    data_dir = os.path.join(cfg["signal_cli_data_dir"], "data")
    for label in missing:
        print(
            f"signal-bot: missing required account file in {data_dir}: {label}",
            file=sys.stderr,
        )
    print(
        "signal-bot: signal-cli account data must be provisioned manually "
        "before setting configured to true!",
        file=sys.stderr,
    )
    sys.exit(1)


def read_profile_state(cfg):
    state = read_json_state(cfg["profile_state_file"])
    return state if isinstance(state, dict) else {}


def profile_fingerprint(cfg):
    digest = hashlib.sha256()
    for key in ("profile_given_name", "profile_about"):
        digest.update(f"{key}={cfg.get(key) or ''}\n".encode())
    digest.update(f"profile_avatar={file_digest(cfg.get('profile_avatar'))}\n".encode())
    digest.update(f"discoverable_by_number={DISCOVERABLE_BY_NUMBER}\n".encode())
    return digest.hexdigest()


def apply_profile(rpc, cfg):
    fingerprint = profile_fingerprint(cfg)
    state = read_profile_state(cfg)
    if state.get("fingerprint") == fingerprint:
        return

    profile_params = {}
    if cfg.get("profile_given_name"):
        profile_params["givenName"] = cfg["profile_given_name"]
    if cfg.get("profile_about") is not None:
        profile_params["about"] = cfg["profile_about"]
    if cfg.get("profile_avatar"):
        profile_params["avatar"] = cfg["profile_avatar"]
    else:
        profile_params["removeAvatar"] = True
    rpc.call_checked("updateProfile", profile_params)

    rpc.call_checked("updateConfiguration", {"typingIndicators": True})
    rpc.call_checked("updateAccount", {"discoverableByNumber": DISCOVERABLE_BY_NUMBER})
    state["fingerprint"] = fingerprint
    write_json_state(cfg["profile_state_file"], state)


def apply_group_avatar(rpc, cfg, group_id):
    digest = file_digest(cfg.get("group_avatar"))
    if not digest:
        return
    state = read_profile_state(cfg)
    if state.get("group_avatar") == digest:
        return
    rpc.call_checked(
        "updateGroup", {"groupId": group_id, "avatar": cfg["group_avatar"]}
    )
    state["group_avatar"] = digest
    write_json_state(cfg["profile_state_file"], state)


def resolve_recipients(rpc, numbers):
    if not numbers:
        return {}
    statuses = rpc.call_checked("getUserStatus", {"recipient": sorted(numbers)})
    mapping = {}
    if isinstance(statuses, list):
        for entry in statuses:
            if not isinstance(entry, dict):
                continue
            number = entry.get("number") or entry.get("recipient")
            uuid = entry.get("uuid")
            if number and uuid:
                mapping[number] = uuid
    return mapping


def group_membership_entries(group, fields):
    entries = []
    for field in fields:
        for member in group.get(field) or []:
            if isinstance(member, dict):
                entries.append((member.get("number"), member.get("uuid")))
            elif isinstance(member, str):
                entries.append((member, None))
    return entries


def collect_identifiers(group, fields):
    numbers = set()
    uuids = set()
    for number, uuid in group_membership_entries(group, fields):
        if number:
            numbers.add(number)
        if uuid:
            uuids.add(uuid)
    return numbers, uuids


def group_member_recipients(group):
    mapping = {}
    for number, uuid in group_membership_entries(group, ("members",)):
        if number and uuid:
            mapping[number] = uuid
    return mapping


def find_group(rpc, group_id):
    groups = rpc.call_checked("listGroups", {"groupId": [group_id], "detailed": True})
    if not isinstance(groups, list):
        return None
    for candidate in groups:
        if isinstance(candidate, dict) and candidate.get("id") == group_id:
            return candidate
    return None


def find_group_by_name(rpc, name):
    groups = rpc.call_checked("listGroups", {"detailed": True})
    if not isinstance(groups, list):
        return None
    for candidate in groups:
        if isinstance(candidate, dict) and candidate.get("name") == name:
            return candidate
    return None


def normalize_permission(value):
    return str(value or "").replace("_", "-").lower()


def restrict_group_access(
    rpc, group_id, restrict_add_member, disable_link, fatal=False
):
    params = {"groupId": group_id}
    if restrict_add_member:
        params["setPermissionAddMember"] = ONLY_ADMINS
    if disable_link:
        params["link"] = GROUP_LINK_DISABLED
    if len(params) == 1:
        return
    try:
        call_with_retry(rpc, "updateGroup", params)
    except RpcError as e:
        if fatal:
            raise TransientError(
                f"could not restrict access to the newly created main group: {e}"
            )
        log_error(f"signal-bot: could not restrict access to the main group: {e}")


def unban_allowed_members(rpc, group, group_id, allowed_numbers, allowed_uuids):
    unban = set()
    for number, uuid in group_membership_entries(group, GROUP_BANNED_FIELDS):
        if number is not None and number in allowed_numbers:
            unban.add(number)
        elif uuid is not None and uuid in allowed_uuids:
            unban.add(uuid)
    if not unban:
        return False
    try:
        call_with_retry(
            rpc, "updateGroup", {"groupId": group_id, "unban": sorted(unban)}
        )
    except RpcError as e:
        log_error(f"signal-bot: could not unban allowed group members: {e}")
        return False
    return True


def create_group(rpc, cfg, allowed_numbers, account):
    result = rpc.call_checked(
        "updateGroup",
        {
            "name": cfg["main_group_name"],
            "members": sorted(allowed_numbers - {account}),
        },
    )
    group_id = result.get("groupId") if isinstance(result, dict) else None
    if not group_id:
        raise TransientError("updateGroup did not return an id for the new group")
    try:
        write_group_id(cfg["group_id_file"], group_id)
    except OSError as e:
        log_error(
            f"signal-bot: created the main group {group_id} but could not persist its "
            f"id ({e}), write it to {cfg['group_id_file']} manually before restarting!"
        )
        raise
    restrict_group_access(rpc, group_id, True, False, fatal=True)
    return group_id


def group_adoption_problem(
    group, allowed_numbers, allowed_uuids, protected_uuids, account
):
    admin_numbers, admin_uuids = collect_identifiers(group, GROUP_ADMIN_FIELDS)
    if account not in admin_numbers and not (admin_uuids & protected_uuids):
        return "the bot account is not an admin of it"
    for number, uuid in group_membership_entries(group, GROUP_PARTICIPANT_FIELDS):
        if number is not None and (number == account or number in allowed_numbers):
            continue
        if uuid is not None and (uuid in allowed_uuids or uuid in protected_uuids):
            continue
        return "it holds participants outside the allowed numbers list"
    return None


def ensure_group(
    rpc,
    cfg,
    allowed_numbers,
    allowed_uuids,
    protected_uuids,
    account,
    resolution_complete,
):
    group_id = read_group_id(cfg["group_id_file"])
    if group_id is not None:
        return group_id

    existing = find_group_by_name(rpc, cfg["main_group_name"])
    if existing is not None:
        group_id = existing.get("id")
        if not group_id:
            raise SystemExit(
                "signal-bot: the existing main group has no id, refusing to create a "
                "second one!"
            )
        problem = group_adoption_problem(
            existing, allowed_numbers, allowed_uuids, protected_uuids, account
        )
        if problem is not None:
            if not resolution_complete:
                raise TransientError(
                    "cannot verify the membership of the existing group named "
                    f"{cfg['main_group_name']!r} while allowed numbers are unresolved"
                )
            raise SystemExit(
                "signal-bot: refusing to adopt the existing group named "
                f"{cfg['main_group_name']!r} because {problem}, rename or delete that "
                "group first!"
            )
        print(
            "signal-bot: adopting the existing main group instead of creating a "
            "second one",
            file=sys.stderr,
        )
        write_group_id(cfg["group_id_file"], group_id)
        return group_id

    return create_group(rpc, cfg, allowed_numbers, account)


def group_admin_updates(group, admin_numbers, recipients, account, allow_removals):
    desired = set(admin_numbers) | {account}
    current_numbers, current_uuids = collect_identifiers(group, GROUP_ADMIN_FIELDS)
    promote = sorted(
        n
        for n in desired
        if n != account
        and n not in current_numbers
        and (recipients.get(n) or n) not in current_uuids
    )
    if not allow_removals:
        return promote, []

    desired_uuids = {recipients[n] for n in desired if recipients.get(n)}
    demote = set()
    for number, uuid in group_membership_entries(group, GROUP_ADMIN_FIELDS):
        if number is not None and (number == account or number in desired):
            continue
        if uuid is not None and uuid in desired_uuids:
            continue
        identifier = number or uuid
        if identifier is not None and identifier != account:
            demote.add(identifier)
    return promote, sorted(demote)


def sync_group_admins(
    rpc, group, group_id, admin_numbers, recipients, account, allow_removals
):
    promote, demote = group_admin_updates(
        group, admin_numbers, recipients, account, allow_removals
    )
    if not promote and not demote:
        return False

    update_params = {"groupId": group_id}
    if promote:
        update_params["admin"] = promote
    if demote:
        update_params["removeAdmin"] = demote
    try:
        call_with_retry(rpc, "updateGroup", update_params)
    except RpcError as e:
        log_error(f"signal-bot: could not sync the group admins: {e}")
        return False
    return True


def stale_group_members(
    group, allowed_numbers, allowed_uuids, protected_uuids, account
):
    stale = set()
    for number, uuid in group_membership_entries(group, GROUP_PARTICIPANT_FIELDS):
        if number is not None and (number == account or number in allowed_numbers):
            continue
        if uuid is not None and (uuid in allowed_uuids or uuid in protected_uuids):
            continue
        identifier = number or uuid
        if identifier is not None and identifier != account:
            stale.add(identifier)
    return sorted(stale)


def sync_group(
    rpc,
    cfg,
    group_id,
    allowed_numbers,
    admin_numbers,
    recipients,
    allowed_uuids,
    protected_uuids,
    account,
    allow_removals,
):
    group = find_group(rpc, group_id)
    if group is None:
        raise GroupMissing()

    if unban_allowed_members(rpc, group, group_id, allowed_numbers, allowed_uuids):
        group = find_group(rpc, group_id) or group

    present_numbers, present_uuids = collect_identifiers(
        group, GROUP_PARTICIPANT_FIELDS
    )
    missing_members = sorted(
        n
        for n in allowed_numbers
        if n != account
        and n not in present_numbers
        and (recipients.get(n) or n) not in present_uuids
    )
    removed_members = (
        stale_group_members(
            group, allowed_numbers, allowed_uuids, protected_uuids, account
        )
        if allow_removals
        else []
    )

    update_params = {}
    if missing_members:
        update_params["members"] = missing_members
    if removed_members:
        update_params["removeMember"] = removed_members
        update_params["ban"] = removed_members
    if group.get("name") != cfg["main_group_name"]:
        update_params["name"] = cfg["main_group_name"]

    if update_params:
        update_params["groupId"] = group_id
        try:
            call_with_retry(rpc, "updateGroup", update_params)
        except RpcError as e:
            log_error(f"signal-bot: could not sync the group: {e}")

    restrict_add_member = (
        normalize_permission(group.get("permissionAddMember")) != ONLY_ADMINS
    )
    disable_link = bool(group.get("groupInviteLink"))
    restrict_group_access(rpc, group_id, restrict_add_member, disable_link)

    group = find_group(rpc, group_id) or group
    if sync_group_admins(
        rpc, group, group_id, admin_numbers, recipients, account, allow_removals
    ):
        group = find_group(rpc, group_id) or group
    return group


def resolve_group_state(rpc, cfg, account, allowed_numbers):
    previous = read_json_state(cfg["recipients_file"]) or {}
    try:
        resolved = resolve_recipients(rpc, allowed_numbers)
        protected_uuids = set(resolve_recipients(rpc, [account]).values())
        resolution_complete = True
    except RpcError as e:
        print(
            "signal-bot: could not resolve the allowed numbers, skipping group "
            f"member removals for this run: {e}",
            file=sys.stderr,
        )
        resolved = {}
        protected_uuids = set()
        resolution_complete = False
    recipients = {**previous, **resolved}
    allowed_uuids = {
        recipients[number] for number in allowed_numbers if recipients.get(number)
    }

    unresolved = [number for number in allowed_numbers if not recipients.get(number)]
    if resolution_complete and unresolved:
        print(
            f"signal-bot: {len(unresolved)} of {len(allowed_numbers)} allowed numbers "
            "have no known uuid, skipping group member removals for this run",
            file=sys.stderr,
        )
        resolution_complete = False

    return recipients, allowed_uuids, protected_uuids, resolution_complete


def bootstrap_once(rpc, cfg, account, allowed_numbers, admin_numbers, resolution):
    apply_profile(rpc, cfg)
    recipients, allowed_uuids, protected_uuids, resolution_complete = resolution
    recipients = dict(recipients)

    def reconcile():
        group_id = ensure_group(
            rpc,
            cfg,
            allowed_numbers,
            allowed_uuids,
            protected_uuids,
            account,
            resolution_complete,
        )
        return group_id, sync_group(
            rpc,
            cfg,
            group_id,
            allowed_numbers,
            admin_numbers,
            recipients,
            allowed_uuids,
            protected_uuids,
            account,
            resolution_complete,
        )

    try:
        group_id, group = reconcile()
    except GroupMissing:
        print(
            "signal-bot: the persisted main group no longer exists on this "
            "account, creating a new one",
            file=sys.stderr,
        )
        forget_group_id(cfg["group_id_file"])
        try:
            group_id, group = reconcile()
        except GroupMissing:
            raise TransientError(
                "the freshly created main group is not visible on this account"
            )
    apply_group_avatar(rpc, cfg, group_id)

    if group is not None:
        for number, uuid in group_member_recipients(group).items():
            recipients.setdefault(number, uuid)
    recipients = {
        number: uuid
        for number, uuid in recipients.items()
        if uuid and number in allowed_numbers
    }
    write_json_state(cfg["recipients_file"], recipients)


def bootstrap(cfg):
    account = require_secret(cfg["account_file"], "phone number")
    ensure_account_provisioned(cfg, account)
    _, contacts_by_number, admin_numbers = load_contacts(cfg, account)
    allowed_numbers = set(contacts_by_number) | {account}

    deadline = time.monotonic() + BOOTSTRAP_RETRY_SECONDS
    attempt = 0
    resolution = None
    while True:
        attempt += 1
        rpc = SignalRpc(cfg["socket_path"], account)
        rpc.start_reader()
        try:
            if resolution is None:
                resolution = resolve_group_state(rpc, cfg, account, allowed_numbers)
            bootstrap_once(
                rpc, cfg, account, allowed_numbers, admin_numbers, resolution
            )
            break
        except (RpcError, TransientError) as e:
            if time.monotonic() >= deadline:
                raise SystemExit(
                    f"signal-bot: bootstrap failed after {attempt} attempts: {e}!"
                )
            print(
                f"signal-bot: bootstrap attempt {attempt} failed, retrying: {e}",
                file=sys.stderr,
            )
        finally:
            rpc.close()
        time.sleep(BOOTSTRAP_RETRY_DELAY)

    print("signal-bot: bootstrap complete")


def markdown_heading_length(text, start):
    index = start
    while index < len(text) and text[index] == "#" and index - start < 6:
        index += 1
    if index == start:
        return 0
    marks = index
    while index < len(text) and text[index] in " \t":
        index += 1
    if index == marks:
        return 0
    return index - start


def markdown_opens(text, index, marker):
    if index > 0 and text[index - 1].isalnum():
        return False
    after = index + len(marker)
    return after < len(text) and not text[after].isspace()


def markdown_marker(text, index):
    for marker, style, literal in MARKDOWN_MARKERS:
        if text.startswith(marker, index) and markdown_opens(text, index, marker):
            return marker, style, literal
    return "", "", False


def markdown_closing(text, marker, start):
    index = start
    while True:
        index = text.find(marker, index)
        if index < 0:
            return -1
        after = index + len(marker)
        if (
            index == start
            or text[index - 1] == "\\"
            or text[index - 1].isspace()
            or (after < len(text) and text[after].isalnum())
        ):
            index = after
            continue
        return index


def markdown_fence_body(block):
    head, newline, rest = block.partition("\n")
    if newline and head.strip() and len(head.split()) == 1:
        block = rest
    return block.strip("\n")


def parse_markdown(text, headings=True):
    parts = []
    ranges = []
    length = 0
    index = 0
    line_start = True

    def emit(body, body_ranges, style=None):
        nonlocal length
        ranges.extend((start + length, span, name) for start, span, name in body_ranges)
        if style:
            ranges.append((length, len(body), style))
        parts.append(body)
        length += len(body)

    while index < len(text):
        char = text[index]
        if (
            char == "\\"
            and index + 1 < len(text)
            and text[index + 1] in MARKDOWN_ESCAPABLE
        ):
            emit(text[index + 1], [])
            index += 2
            line_start = False
            continue
        if headings and line_start and char == "#":
            marks = markdown_heading_length(text, index)
            if marks:
                stop = text.find("\n", index + marks)
                if stop < 0:
                    stop = len(text)
                body, body_ranges = parse_markdown(text[index + marks : stop], False)
                if body:
                    emit(body, body_ranges, "BOLD")
                index = stop
                line_start = False
                continue
        if text.startswith(MARKDOWN_FENCE, index):
            stop = text.find(MARKDOWN_FENCE, index + len(MARKDOWN_FENCE))
            if stop >= 0:
                body = markdown_fence_body(text[index + len(MARKDOWN_FENCE) : stop])
                if body:
                    emit(body, [], "MONOSPACE")
                index = stop + len(MARKDOWN_FENCE)
                line_start = False
                continue
        marker, style, literal = markdown_marker(text, index)
        if marker:
            stop = markdown_closing(text, marker, index + len(marker))
            if stop >= 0:
                inner = text[index + len(marker) : stop]
                body, body_ranges = (
                    (inner, []) if literal else parse_markdown(inner, False)
                )
                if body:
                    emit(body, body_ranges, style)
                index = stop + len(marker)
                line_start = False
                continue
        emit(char, [])
        line_start = char == "\n"
        index += 1
    return "".join(parts), ranges


def render_markdown(cfg, text):
    if not cfg["markdown"]:
        return text, []
    return parse_markdown(text)


def markdown_emphasis(cfg, text, marker):
    stripped = text.strip()
    if not cfg["markdown"] or not stripped:
        return text
    return f"{marker}{stripped}{marker}"


def format_outbound_text(cfg, title, message, url):
    parts = []
    ranges = []
    length = 0
    if title:
        parts.append(title)
        if cfg["bold_title"]:
            ranges.append((0, len(title), "BOLD"))
        length += len(title)
        parts.append("\n\n")
        length += 2
    body, body_ranges = render_markdown(cfg, message)
    ranges.extend((start + length, span, style) for start, span, style in body_ranges)
    parts.append(body)
    if url:
        parts.append(f"\n\n{url}")
    return "".join(parts), ranges


def utf16_length(text):
    return len(text.encode("utf-16-le")) // 2


def truncate_to_bytes(text, limit):
    encoded = text.encode("utf-8")
    if len(encoded) <= limit:
        return text
    return encoded[:limit].decode("utf-8", "ignore")


def take_chunk(text, limit):
    encoded = text.encode("utf-8")
    if len(encoded) <= limit:
        return text, ""
    head = encoded[:limit].decode("utf-8", "ignore")
    newline = head.rfind("\n")
    if newline > 0:
        return head[:newline], text[newline + 1 :]
    return head, text[len(head) :]


def split_message(text, max_messages):
    chunks = []
    remaining = text
    offset = 0
    while remaining and len(chunks) < max_messages:
        chunk, remaining = take_chunk(remaining, MAX_MESSAGE_BYTES)
        chunks.append((chunk, offset, len(chunk)))
        offset = len(text) - len(remaining)
    if not chunks:
        return [(text, 0, len(text))]
    if remaining:
        print(
            f"signal-bot: outbound message truncated after {len(chunks)} parts",
            file=sys.stderr,
        )
        limit = MAX_MESSAGE_BYTES - len(MESSAGE_ELLIPSIS.encode("utf-8"))
        chunk, chunk_offset, _ = chunks[-1]
        kept = truncate_to_bytes(chunk, limit)
        chunks[-1] = (kept + MESSAGE_ELLIPSIS, chunk_offset, len(kept))
    return chunks


def chunk_text_styles(chunk, offset, span, ranges):
    styles = []
    for start, length, style in ranges:
        first = max(start, offset)
        last = min(start + length, offset + span)
        if last <= first:
            continue
        begin = first - offset
        styles.append(
            f"{utf16_length(chunk[:begin])}:"
            f"{utf16_length(chunk[begin : last - offset])}:{style}"
        )
    return styles


def build_quote(timestamp, author, text, attachments=None):
    if not timestamp or not author:
        return None
    quote = {
        "quoteTimestamp": timestamp,
        "quoteAuthor": author,
        "quoteMessage": (text or "")[:QUOTE_TEXT_LIMIT],
    }
    if attachments:
        quote["quoteAttachments"] = attachments
    return quote


def quote_attachment_specs(attachment):
    content_type = attachment.get("contentType")
    if not isinstance(content_type, str) or not content_type or ":" in content_type:
        return None
    filename = attachment.get("filename")
    if isinstance(filename, str) and filename and ":" not in filename:
        return [f"{content_type}:{filename}"]
    return [content_type]


def collapse_quote_context(text):
    collapsed = " ".join(text.split())
    if len(collapsed) <= QUOTE_CONTEXT_LIMIT:
        return collapsed
    return collapsed[:QUOTE_CONTEXT_LIMIT] + "..."


def with_quote_context(cfg, author, quoted, text):
    values = {
        "author": author or message_text(cfg, "quote_context_user"),
        "message": collapse_quote_context(quoted),
        "text": text,
    }
    try:
        return message_text(cfg, "quote_context_template").format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid quote context template, using the default",
            file=sys.stderr,
        )
        return f"{values['author']}: {values['message']}\n{values['text']}"


def with_group_speaker(cfg, author, text):
    values = {"author": author, "text": text}
    try:
        return message_text(cfg, "group_speaker_template").format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid group speaker template, using the default",
            file=sys.stderr,
        )
        return f"{values['author']}: {values['text']}"


def render_recap(cfg, entries, max_chars, keep_newest=True):
    template = message_text(cfg, "context_recap_entry_template")
    ordered = list(reversed(entries)) if keep_newest else list(entries)
    lines = []
    total = 0
    for author, message in ordered:
        values = {"author": author, "message": collapse_quote_context(message)}
        try:
            line = template.format(**values)
        except (KeyError, IndexError):
            print(
                "signal-bot: invalid context recap entry template, using the default",
                file=sys.stderr,
            )
            line = f"{values['author']}: {values['message']}"
        if lines and total + len(line) > max_chars:
            break
        lines.append(line)
        total += len(line)
    if keep_newest:
        lines.reverse()
    return "\n".join(lines)


def with_script_description(cfg, text, command):
    description = command.get("description")
    if not description:
        return text
    values = {"text": text, "description": description}
    try:
        return message_text(cfg, "script_recap_template").format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid script recap template, using the default",
            file=sys.stderr,
        )
        return f"{values['text']} ({values['description']})"


def with_context_recap(cfg, transcript, text):
    values = {"transcript": transcript, "text": text}
    try:
        return message_text(cfg, "context_recap_template").format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid context recap template, using the default",
            file=sys.stderr,
        )
        return f"{values['transcript']}\n{values['text']}"


def normalize_emoji(value):
    if not isinstance(value, str):
        return ""
    return "".join(
        char
        for char in value
        if char not in EMOJI_VARIATION_SELECTORS
        and not EMOJI_SKIN_TONE_FIRST <= char <= EMOJI_SKIN_TONE_LAST
    )


def build_reaction_meanings(cfg):
    meanings = {}
    for entry in cfg["reactions"]["emoji"].values():
        if not isinstance(entry, dict):
            continue
        meaning = entry.get("meaning")
        if not isinstance(meaning, str):
            continue
        for emoji in entry.get("emoji") or []:
            key = normalize_emoji(emoji)
            if key:
                meanings.setdefault(key, meaning)
    return meanings


def reaction_meaning(meanings, fallback, emoji):
    key = normalize_emoji(emoji)
    meaning = meanings.get(key)
    if meaning is None and EMOJI_ZWJ in key:
        meaning = meanings.get(key.split(EMOJI_ZWJ, 1)[0])
    if meaning is None:
        meaning = fallback
    try:
        return meaning.format(emoji=emoji or "")
    except (KeyError, IndexError):
        return meaning


def wrap_instruction(template, instruction):
    values = {"instruction": instruction}
    try:
        return template.format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid instruction template, using the default",
            file=sys.stderr,
        )
        return f"[{values['instruction']}]"


def reaction_prompt(template, instruction, emoji, meaning):
    values = {"instruction": instruction, "emoji": emoji or "", "meaning": meaning}
    try:
        return template.format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid reaction prompt template, using the default",
            file=sys.stderr,
        )
        return f"{values['instruction']} {values['emoji']} {values['meaning']}"


def transcription_prompt(template, instruction, transcript):
    values = {"instruction": instruction, "transcript": transcript}
    try:
        return template.format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid transcription prompt template, using the default",
            file=sys.stderr,
        )
        return f"{values['instruction']} {values['transcript']}"


def attachment_file(attachments_dir, attachment):
    name = attachment.get("id")
    if not isinstance(name, str) or not name or os.sep in name:
        return None
    path = os.path.realpath(os.path.join(attachments_dir, name))
    root = os.path.realpath(attachments_dir) + os.sep
    if not path.startswith(root):
        print(
            "signal-bot: rejecting an attachment outside its directory", file=sys.stderr
        )
        return None
    return path


def discard_attachment(attachments_dir, attachment):
    path = attachment_file(attachments_dir, attachment)
    if path is None:
        return
    for candidate in (path, f"{path}.preview"):
        try:
            os.unlink(candidate)
        except FileNotFoundError:
            pass
        except OSError as e:
            print(f"signal-bot: cannot delete {candidate}: {e}", file=sys.stderr)


def is_audio_attachment(attachment):
    content_type = attachment.get("contentType")
    return isinstance(content_type, str) and content_type.startswith("audio/")


def select_audio_attachment(attachments):
    for attachment in attachments:
        if isinstance(attachment, dict) and is_audio_attachment(attachment):
            return attachment
    return None


def run_transcription_step(argv, timeout, label):
    try:
        result = subprocess.run(
            argv,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            start_new_session=True,
        )
    except subprocess.TimeoutExpired:
        print(f"signal-bot: {label} timed out after {timeout}s", file=sys.stderr)
        return None
    except OSError as e:
        print(f"signal-bot: cannot run {label}: {e}", file=sys.stderr)
        return None
    if result.returncode != 0:
        details = result.stderr.decode("utf-8", "replace").strip().splitlines()
        print(
            f"signal-bot: {label} failed: {details[-1] if details else result.returncode}",
            file=sys.stderr,
        )
        return None
    return result.stdout


def transcribe_audio(transcription_config, source):
    timeout = transcription_config["timeout_seconds"]
    placeholder = transcription_config["audio_placeholder"]
    with tempfile.TemporaryDirectory() as workdir:
        wav = os.path.join(workdir, "audio.wav")
        if (
            run_transcription_step(
                [
                    transcription_config["ffmpeg"],
                    "-nostdin",
                    "-loglevel",
                    "error",
                    "-i",
                    source,
                    "-t",
                    str(transcription_config["max_duration_seconds"]),
                    "-ar",
                    "16000",
                    "-ac",
                    "1",
                    "-c:a",
                    "pcm_s16le",
                    "-f",
                    "wav",
                    wav,
                ],
                timeout,
                "the audio transcode",
            )
            is None
        ):
            return None
        stdout = run_transcription_step(
            [
                part.replace(placeholder, wav)
                for part in transcription_config["transcribe_command"]
            ],
            timeout,
            "the transcription",
        )
    if stdout is None:
        return None
    transcript = " ".join(stdout.decode("utf-8", "replace").split())
    if not transcript:
        print("signal-bot: the transcription came back empty", file=sys.stderr)
        return None
    return transcript


def reaction_targets_account(reaction, account):
    number = reaction.get("targetAuthorNumber") or reaction.get("targetAuthor")
    if isinstance(number, str) and number.startswith("+"):
        return number == account
    return True


def quote_author_label(cfg, contacts_by_number, account, number):
    if number and number == account:
        return message_text(cfg, "quote_context_bot")
    return contacts_by_number.get(number) or message_text(cfg, "quote_context_user")


def notice_key(target):
    group_id = target.get("groupId")
    if group_id:
        return f"group:{group_id}"
    recipients = target.get("recipient")
    if isinstance(recipients, list) and len(recipients) == 1:
        return f"direct:{recipients[0]}"
    return None


def describe_response(body):
    if isinstance(body, dict):
        return f"object with keys {sorted(body)}"
    return type(body).__name__


class RefuseRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


HA_OPENER = urllib.request.build_opener(RefuseRedirect)


def request_ha_conversation(
    cfg, ha_token, text, conversation_id=None, agent_override=None
):
    request_body = {"text": text, "language": cfg["ha_language"]}
    agent_id = agent_override or cfg.get("ha_agent_id")
    if agent_id:
        request_body["agent_id"] = agent_id
    if conversation_id:
        request_body["conversation_id"] = conversation_id
    payload = json.dumps(request_body).encode()
    req = urllib.request.Request(
        f"{cfg['ha_url'].rstrip('/')}/api/conversation/process",
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {ha_token}",
            "Content-Type": "application/json",
        },
    )
    timeout = cfg["ha_timeout_seconds"]
    try:
        with HA_OPENER.open(req, timeout=timeout) as resp:
            body = json.loads(resp.read())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
        print(
            f"signal-bot: Home Assistant conversation request failed: {e}",
            file=sys.stderr,
        )
        return message_text(cfg, "ha_unreachable"), None
    try:
        speech = body["response"]["speech"]["plain"]["speech"]
    except (KeyError, TypeError):
        print(
            f"signal-bot: unexpected Home Assistant response: {describe_response(body)}",
            file=sys.stderr,
        )
        return message_text(cfg, "ha_unexpected_response"), None
    new_id = body.get("conversation_id")
    return speech, new_id if isinstance(new_id, str) else None


def contains_tool_call_artifact(speech):
    return isinstance(speech, str) and TOOL_CALL_ARTIFACT_PATTERN.search(speech)


def group_filter_context(template, transcript, prompt):
    values = {"transcript": transcript, "prompt": prompt}
    try:
        return template.format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid group filter context template, using the default",
            file=sys.stderr,
        )
        return f"[{values['transcript']}]\n{values['prompt']}"


def group_filter_prompt(template, instruction, prompt):
    if not instruction:
        return prompt
    values = {"instruction": instruction, "prompt": prompt}
    try:
        return template.format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid group filter prompt template, using the default",
            file=sys.stderr,
        )
        return f"{values['instruction']}\n{values['prompt']}"


def group_filter_verdict(silent_answers, maybe_answers, speech):
    if not isinstance(speech, str):
        return "answer"
    match = re.search(r"\w+", speech)
    if match is None:
        return "answer"
    word = match.group(0).casefold()
    if word in silent_answers:
        return "silent"
    if word in maybe_answers:
        return "maybe"
    return "answer"


class MaybeBudget:
    def __init__(self, limit, window_seconds):
        self.limit = limit
        self.window = window_seconds
        self.events = {}
        self.lock = threading.Lock()

    def allow(self, key):
        if self.limit <= 0:
            return False
        now = time.monotonic()
        with self.lock:
            stamps = [t for t in self.events.get(key, ()) if now - t < self.window]
            if len(stamps) >= self.limit:
                self.events[key] = stamps
                return False
            stamps.append(now)
            self.events[key] = stamps
            return True

    def remaining(self, key):
        now = time.monotonic()
        with self.lock:
            stamps = [t for t in self.events.get(key, ()) if now - t < self.window]
            self.events[key] = stamps
            return max(self.limit - len(stamps), 0)


def call_ha_conversation(
    cfg, ha_token, text, conversation_id=None, agent_override=None
):
    attempts = len(HA_AGENT_ERROR_RETRY_DELAYS) + 1
    for attempt in range(attempts):
        speech, new_id = request_ha_conversation(
            cfg, ha_token, text, conversation_id, agent_override
        )
        if not isinstance(speech, str) or speech.strip() != HA_AGENT_ERROR_SPEECH:
            if contains_tool_call_artifact(speech):
                log_error(
                    "signal-bot: the Home Assistant conversation agent wrote a tool "
                    "call into its reply instead of running it, the requested action "
                    "did not happen"
                )
                return message_text(cfg, "ha_tool_call_artifact"), new_id
            return speech, new_id
        print(
            f"signal-bot: Home Assistant conversation agent failed on attempt "
            f"{attempt + 1} of {attempts}: {speech.strip()}",
            file=sys.stderr,
        )
        if attempt + 1 < attempts:
            time.sleep(HA_AGENT_ERROR_RETRY_DELAYS[attempt])
    return message_text(cfg, "ha_agent_failed"), None


def ha_reachable(ha_url, ha_token):
    req = urllib.request.Request(
        f"{ha_url.rstrip('/')}/api/",
        headers={"Authorization": f"Bearer {ha_token}"},
    )
    try:
        with HA_OPENER.open(req, timeout=10) as resp:
            return resp.status == 200
    except (urllib.error.URLError, TimeoutError):
        return False


def command_message(cfg, key, name, override=None, argument=""):
    template = override or message_text(cfg, key)
    return template.replace("{command}", name).replace("{argument}", argument)


def split_command(text):
    parts = text.strip().split(None, 1)
    name = parts[0] if parts else ""
    argument = parts[1].strip() if len(parts) > 1 else ""
    return name, argument


def script_argument_problem(cfg, name, command, argument):
    mode = command.get("argument", "none")
    if not argument:
        if mode == "required":
            return command_message(cfg, "script_argument_required", name)
        return None
    if mode == "none":
        return command_message(cfg, "script_argument_not_allowed", name)
    if len(argument) > command["max_argument_length"]:
        return command_message(cfg, "script_argument_too_long", name)
    if any((ord(ch) < 32 and ch not in "\t\n") or ord(ch) == 127 for ch in argument):
        return command_message(cfg, "script_argument_invalid", name)
    return None


def script_response_text(response):
    if not isinstance(response, dict) or not response:
        return None
    message = response.get("message")
    if isinstance(message, str) and message.strip():
        return message
    return json.dumps(response, sort_keys=True)


def call_ha_script(cfg, ha_token, name, command, argument):
    variables = {}
    if command.get("argument", "none") != "none":
        variables[command["argument_variable"]] = argument
    base_url = f"{cfg['ha_url'].rstrip('/')}/api/services/script"
    if command.get("async"):
        url = f"{base_url}/turn_on"
        request_body = {"entity_id": f"script.{command['script']}"}
        if variables:
            request_body["variables"] = variables
    else:
        url = f"{base_url}/{command['script']}?return_response"
        request_body = variables
    req = urllib.request.Request(
        url,
        data=json.dumps(request_body).encode(),
        method="POST",
        headers={
            "Authorization": f"Bearer {ha_token}",
            "Content-Type": "application/json",
        },
    )
    try:
        script_timeout = command.get("timeout_seconds") or cfg["ha_timeout_seconds"]
        with HA_OPENER.open(req, timeout=script_timeout) as resp:
            body = json.loads(resp.read())
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
        print(
            f"signal-bot: the Home Assistant script {command['script']} failed: {e}",
            file=sys.stderr,
        )
        return command_message(
            cfg, "script_failed", name, command.get("failed_message"), argument
        )
    response = (
        None
        if command.get("async")
        else script_response_text(
            body.get("service_response") if isinstance(body, dict) else None
        )
    )
    if response is not None:
        return response
    return command_message(
        cfg, "script_completed", name, command.get("completed_message"), argument
    )


class Command:
    def __init__(self, description_key, handler):
        self.description_key = description_key
        self.handler = handler


COMMANDS = {}


def register_command(name, description_key):
    def decorator(handler):
        COMMANDS[name] = Command(description_key, handler)
        return handler

    return decorator


@register_command("/status", "help_status_description")
def cmd_status(cfg, ha_token, account, budget_report, maybe_report, hooks_report):
    account_ok = not missing_account_files(cfg, account)
    ha_ok = ha_reachable(cfg["ha_url"], ha_token)
    account_key = "status_account_ok" if account_ok else "status_account_missing"
    ha_key = "status_ha_reachable" if ha_ok else "status_ha_unreachable"
    return (
        message_text(cfg, "status_template")
        .replace("{name}", cfg.get("profile_given_name") or "")
        .replace(
            "{account}", markdown_emphasis(cfg, message_text(cfg, account_key), "**")
        )
        .replace(
            "{homeAssistant}", markdown_emphasis(cfg, message_text(cfg, ha_key), "**")
        )
        .replace("{budget}", budget_report())
        .replace("{maybeBudget}", maybe_report())
        .replace("{hooks}", hooks_report())
    )


@register_command("/help", "help_help_description")
def cmd_help(cfg, ha_token, account, budget_report, maybe_report, hooks_report):
    template = message_text(cfg, "help_entry_template")
    entries = {
        name: message_text(cfg, command.description_key)
        for name, command in COMMANDS.items()
    }
    labels = {}
    for name, command in (cfg.get("script_commands") or {}).items():
        entries[name] = command["description"]
        shortcut = command.get("shortcut")
        if shortcut:
            labels[name] = (
                message_text(cfg, "help_shortcut_template")
                .replace("{command}", name)
                .replace("{shortcut}", shortcut)
            )
    return "\n".join(
        template.replace(
            "{command}", markdown_emphasis(cfg, labels.get(name, name), "**")
        ).replace("{description}", markdown_emphasis(cfg, description, "*"))
        for name, description in sorted(entries.items())
    )


def handle_command(
    cfg, ha_token, account, text, budget_report, maybe_report, hooks_report
):
    words = text.strip().split()
    name = words[0] if words else ""
    command = COMMANDS.get(name, COMMANDS["/help"])
    return command.handler(
        cfg, ha_token, account, budget_report, maybe_report, hooks_report
    )


def is_fresh(timestamp_ms, max_age_seconds):
    if isinstance(timestamp_ms, bool) or not isinstance(timestamp_ms, (int, float)):
        return False
    age = time.time() - timestamp_ms / 1000.0
    return -CLOCK_SKEW_TOLERANCE_SECONDS <= age <= max_age_seconds


class HandledMessages:
    def __init__(self, path, limit):
        self.path = path
        self.limit = limit
        stored = read_json_state(path)
        self.order = (
            [key for key in stored if isinstance(key, str)]
            if isinstance(stored, list)
            else []
        )
        self.keys = set(self.order)
        self.lock = threading.Lock()

    def claim(self, key):
        with self.lock:
            if key in self.keys:
                return False
            self.keys.add(key)
            self.order.append(key)
            while len(self.order) > self.limit:
                self.keys.discard(self.order.pop(0))
            try:
                write_json_state(self.path, self.order)
            except OSError as e:
                log_error(
                    f"signal-bot: could not persist the handled message history: {e}"
                )
        return True


def follow_up_window(cfg):
    start = cfg["night_start_hour"]
    end = cfg["night_end_hour"]
    if start == end:
        return cfg["conversation_follow_up_seconds"]
    hour = time.localtime().tm_hour
    if start < end:
        night = start <= hour < end
    else:
        night = hour >= start or hour < end
    if night:
        return cfg["night_follow_up_seconds"]
    return cfg["conversation_follow_up_seconds"]


class ConversationTracker:
    def __init__(self, limit, follow_up_window, max_messages, reactable_messages):
        self.limit = limit
        self.follow_up_window = follow_up_window
        self.max_messages = max_messages
        self.reactable_messages = reactable_messages
        self.lock = threading.Lock()
        self.by_quote = {}
        self.quote_order = []
        self.by_thread = {}
        self.by_notice = {}
        self.notice_order = []
        self.latest_notice = {}
        self.reactable = {}

    def _prune_threads(self):
        now = time.monotonic()
        window = self.follow_up_window()
        expired = [
            key for key, entry in self.by_thread.items() if now - entry["seen"] > window
        ]
        for key in expired:
            del self.by_thread[key]

    def _live_thread(self, thread_key):
        entry = self.by_thread.get(thread_key)
        if entry is None:
            return None
        if time.monotonic() - entry["seen"] > self.follow_up_window():
            del self.by_thread[thread_key]
            return None
        return entry

    def _touch_thread(self, thread_key):
        entry = self.by_thread.get(thread_key)
        if entry is None:
            entry = {"id": None, "ha": 0.0, "recap": False, "log": [], "pending": []}
            self.by_thread[thread_key] = entry
        entry["seen"] = time.monotonic()
        return entry

    def resolve_quote(self, thread_key, quote_id):
        if quote_id is None:
            return None
        with self.lock:
            return self.by_quote.get((thread_key, quote_id))

    def resolve_thread(self, thread_key, session_seconds):
        with self.lock:
            entry = self._live_thread(thread_key)
            if entry is None or entry["id"] is None:
                return None
            if time.monotonic() - entry["ha"] > session_seconds:
                return None
            return entry["id"]

    def needs_recap(self, thread_key):
        with self.lock:
            entry = self._live_thread(thread_key)
            return bool(entry and entry["recap"])

    def transcript(self, thread_key):
        with self.lock:
            entry = self._live_thread(thread_key)
            return list(entry["log"]) if entry else []

    def pending_turns(self, thread_key):
        with self.lock:
            entry = self._live_thread(thread_key)
            return list(entry["pending"]) if entry else []

    def remember_turn(self, thread_key, author, text, pending=False):
        if thread_key is None or not text:
            return
        with self.lock:
            entry = self._touch_thread(thread_key)
            entry["log"].append((author, text))
            del entry["log"][: -self.max_messages]
            if pending:
                entry["pending"].append((author, text))
                del entry["pending"][: -self.max_messages]
            self._prune_threads()

    def remember_thread(
        self, thread_key, conversation_id, recap_sent=False, drift=False
    ):
        with self.lock:
            entry = self._touch_thread(thread_key)
            entry["id"] = conversation_id
            if conversation_id is not None:
                entry["ha"] = time.monotonic()
            if recap_sent:
                entry["recap"] = False
                entry["pending"].clear()
            elif drift:
                entry["recap"] = True
            self._prune_threads()

    def remember_quote(self, thread_key, sent_timestamp, conversation_id):
        if thread_key is None or sent_timestamp is None or conversation_id is None:
            return
        key = (thread_key, sent_timestamp)
        with self.lock:
            if key in self.by_quote:
                return
            self.by_quote[key] = conversation_id
            self.quote_order.append(key)
            while len(self.quote_order) > self.limit:
                self.by_quote.pop(self.quote_order.pop(0), None)

    def remember_notice(self, target_key, sent_timestamp, text, latest):
        if target_key is None or sent_timestamp is None or not text:
            return
        key = (target_key, sent_timestamp)
        with self.lock:
            if key not in self.by_notice:
                self.by_notice[key] = text
                self.notice_order.append(key)
                while len(self.notice_order) > self.limit:
                    self.by_notice.pop(self.notice_order.pop(0), None)
            if latest:
                self.latest_notice[target_key] = (text, time.monotonic())

    def notice_text(self, target_keys, quote_id):
        if quote_id is None:
            return None
        with self.lock:
            for key in target_keys:
                text = self.by_notice.get((key, quote_id))
                if text is not None:
                    return text
        return None

    def remember_reactable(self, target_key, timestamps, conversation_id, text):
        if target_key is None or not timestamps:
            return
        with self.lock:
            entries = self.reactable.setdefault(target_key, [])
            entries.append((set(timestamps), conversation_id, text, time.monotonic()))
            del entries[: -self.reactable_messages]

    def claim_reactable(self, target_keys, timestamp, max_age):
        if timestamp is None:
            return None
        with self.lock:
            for key in target_keys:
                entries = self.reactable.get(key)
                if not entries:
                    continue
                for index, entry in enumerate(entries):
                    if timestamp not in entry[0]:
                        continue
                    del entries[index]
                    if not entries:
                        del self.reactable[key]
                    age = time.monotonic() - entry[3]
                    if age > max_age:
                        return None
                    return entry[1], entry[2], age
        return None

    def recent_notice(self, target_keys):
        now = time.monotonic()
        window = self.follow_up_window()
        with self.lock:
            for key in target_keys:
                entry = self.latest_notice.get(key)
                if entry is None:
                    continue
                text, seen = entry
                if now - seen > window:
                    del self.latest_notice[key]
                    continue
                return text
        return None


class GroupActivity:
    def __init__(self):
        self.lock = threading.Lock()
        self.counts = {}

    def note(self, group_id):
        with self.lock:
            count = self.counts.get(group_id, 0) + 1
            self.counts[group_id] = count
            return count

    def count(self, group_id):
        with self.lock:
            return self.counts.get(group_id, 0)


def is_recent_timestamp(value, now, window=3600):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False
    return 0 <= now - value < window


class AllowedUuids:
    def __init__(self, path, contact_numbers):
        self.path = path
        self.contact_numbers = contact_numbers
        self.stamp = None
        self.checked = 0.0
        self.uuids = set()
        self.numbers = {}
        self._reload()

    def _reload(self):
        self.checked = time.monotonic()
        try:
            stamp = os.stat(self.path).st_mtime_ns
        except OSError:
            return
        if stamp == self.stamp:
            return
        recipients = read_json_state(self.path)
        if not isinstance(recipients, dict):
            return
        self.numbers = {
            uuid: number
            for number, uuid in recipients.items()
            if uuid and number in self.contact_numbers
        }
        self.uuids = set(self.numbers)
        self.stamp = stamp

    def holds(self, uuid):
        if time.monotonic() - self.checked >= RECIPIENTS_RECHECK_SECONDS:
            self._reload()
        if uuid in self.uuids:
            return True
        self._reload()
        return uuid in self.uuids

    def number_for(self, uuid):
        if uuid is None:
            return None
        return self.numbers.get(uuid)

    def uuid_for(self, number):
        if number is None:
            return None
        for uuid, value in self.numbers.items():
            if value == number:
                return uuid
        return None


class RejectionCounter:
    def __init__(self, interval):
        self.interval = interval
        self.lock = threading.Lock()
        self.count = 0
        self.logged = time.monotonic() - interval

    def record(self):
        with self.lock:
            self.count += 1
            now = time.monotonic()
            if now - self.logged < self.interval:
                return
            count = self.count
            self.count = 0
            self.logged = now
        print(
            f"signal-bot: discarded {count} inbound messages from senders that "
            "are not configured contacts",
            file=sys.stderr,
        )


class SenderBudget:
    def __init__(self, limit, window, input_chars, output_chars, state_path=None):
        self.limit = limit
        self.window = window
        self.input_chars = input_chars
        self.output_chars = output_chars
        self.state_path = state_path
        self.lock = threading.Lock()
        self.notified = set()
        self.hits = self._load()

    def _load(self):
        stored = read_json_state(self.state_path) if self.state_path else None
        if not isinstance(stored, dict):
            return {}
        now = time.time()
        loaded = {}
        for key, values in stored.items():
            if not isinstance(key, str) or not isinstance(values, list):
                continue
            recent = self._recent(values, now)
            if recent:
                loaded[key] = recent
        return loaded

    def _is_entry(self, entry):
        if not isinstance(entry, list) or len(entry) != 2:
            return False
        cost = entry[1]
        return not isinstance(cost, bool) and isinstance(cost, (int, float))

    def _recent(self, values, now):
        return [
            entry
            for entry in values
            if self._is_entry(entry) and is_recent_timestamp(entry[0], now, self.window)
        ]

    def _persist(self):
        if not self.state_path:
            return
        try:
            write_json_state(self.state_path, self.hits)
        except OSError as e:
            log_error(f"signal-bot: could not persist the sender budget state: {e}")

    def _record(self, key, cost, now):
        recent = self._recent(self.hits.get(key, []), now)
        if cost > 0:
            recent.append([now, cost])
        self.hits[key] = recent
        self._persist()

    def claim(self, key, text, notify=True):
        now = time.time()
        cost = len(text) / self.input_chars
        with self.lock:
            recent = self._recent(self.hits.get(key, []), now)
            exhausted = sum(entry[1] for entry in recent) >= self.limit
            if exhausted:
                first = notify and key not in self.notified
                if notify:
                    self.notified.add(key)
                self.hits[key] = recent
                self._persist()
            else:
                first = False
                self.notified.discard(key)
                self._record(key, cost, now)
        return not exhausted, first

    def charge(self, key, text):
        now = time.time()
        cost = len(text) / self.output_chars
        with self.lock:
            self._record(key, cost, now)

    def charge_context(self, key, text):
        now = time.time()
        cost = RECAP_BUDGET_WEIGHT * len(text) / self.input_chars
        with self.lock:
            self._record(key, cost, now)

    def used(self, key):
        now = time.time()
        with self.lock:
            return sum(entry[1] for entry in self._recent(self.hits.get(key, []), now))


class SendQueue:
    def __init__(
        self, max_queue_depth, max_sends_per_hour, max_sends_per_minute, state_path=None
    ):
        self.queue = Queue(maxsize=max_queue_depth)
        self.max_sends_per_hour = max_sends_per_hour
        self.max_sends_per_minute = max_sends_per_minute
        self.state_path = state_path
        self.sent_timestamps = self._load_timestamps()
        self.deferred_until = 0.0

    def _load_timestamps(self):
        stored = read_json_state(self.state_path) if self.state_path else None
        if not isinstance(stored, list):
            return []
        now = time.time()
        return [t for t in stored if is_recent_timestamp(t, now)]

    def _persist_timestamps(self):
        if not self.state_path:
            return
        try:
            write_json_state(self.state_path, self.sent_timestamps)
        except OSError as e:
            log_error(f"signal-bot: could not persist the send rate state: {e}")

    def try_enqueue(self, job):
        try:
            self.queue.put_nowait(job)
            return True
        except Full:
            return False

    def defer(self, seconds):
        if not seconds or seconds <= 0:
            return
        until = time.monotonic() + min(seconds, SEND_DEFER_MAX_SECONDS)
        self.deferred_until = max(self.deferred_until, until)

    def _window_wait(self, now, window, limit):
        recent = [t for t in self.sent_timestamps if now - t < window]
        if len(recent) < limit:
            return 0.0
        return min(window, max(0.0, window - (now - min(recent))))

    def _seconds_until_budget(self):
        now = time.time()
        self.sent_timestamps = [
            t for t in self.sent_timestamps if is_recent_timestamp(t, now)
        ]
        return max(
            self._window_wait(now, 3600.0, self.max_sends_per_hour),
            self._window_wait(
                now, SEND_BURST_WINDOW_SECONDS, self.max_sends_per_minute
            ),
            self.deferred_until - time.monotonic(),
        )

    def wait_for_budget(self):
        wait = self._seconds_until_budget()
        if wait <= 0:
            return
        print(
            f"signal-bot: deferring the next send for {int(wait) + 1}s",
            file=sys.stderr,
        )
        while wait > 0:
            time.sleep(min(wait + 0.1, DEFER_POLL_SECONDS))
            wait = self._seconds_until_budget()

    def run(self, send_fn):
        while True:
            try:
                job = self.queue.get(timeout=1)
            except Empty:
                continue
            self.wait_for_budget()
            try:
                sent = send_fn(job) or 1
                now = time.time()
                self.sent_timestamps.extend([now] * sent)
                self._persist_timestamps()
            except Exception as e:
                print(
                    f"signal-bot: send failed: {type(e).__name__}: {e}",
                    file=sys.stderr,
                )
            time.sleep(SEND_PACING_SECONDS)


def today_string():
    return time.strftime("%Y-%m-%d", time.localtime())


def parse_hook_time(value):
    hour, minute = value.split(":")
    return int(hour), int(minute)


def window_instance(now, start_hm, end_hm, day_offset):
    base = time.localtime(now + day_offset * SECONDS_PER_DAY)
    start_hour, start_minute = start_hm
    end_hour, end_minute = end_hm
    open_epoch = time.mktime(
        (base.tm_year, base.tm_mon, base.tm_mday, start_hour, start_minute, 0, 0, 0, -1)
    )
    crosses_midnight = (end_hour, end_minute) <= (start_hour, start_minute)
    close_base = time.localtime(
        open_epoch + (SECONDS_PER_DAY if crosses_midnight else 0)
    )
    close_epoch = time.mktime(
        (
            close_base.tm_year,
            close_base.tm_mon,
            close_base.tm_mday,
            end_hour,
            end_minute,
            0,
            0,
            0,
            -1,
        )
    )
    key = time.strftime("%Y-%m-%d", time.localtime(open_epoch))
    return open_epoch, close_epoch, key


def current_window(now, start_hm, end_hm):
    best = None
    for offset in (-1, 0, 1):
        open_epoch, close_epoch, key = window_instance(now, start_hm, end_hm, offset)
        if open_epoch <= now < close_epoch:
            return open_epoch, close_epoch, key, True
        if open_epoch > now and (best is None or open_epoch < best[0]):
            best = (open_epoch, close_epoch, key)
    if best is None:
        return (*window_instance(now, start_hm, end_hm, 0), False)
    return (*best, False)


class DailyTranscript:
    def __init__(self, limit=DAILY_TRANSCRIPT_LIMIT):
        self.limit = limit
        self.lock = threading.Lock()
        self.day = None
        self.entries = []
        self.user_count = 0
        self.last_bot = None
        self.last_user = None

    def _roll_locked(self):
        lt = time.localtime()
        today = (lt.tm_year, lt.tm_yday)
        if today != self.day:
            self.day = today
            self.entries = []
            self.user_count = 0

    def record(self, author, text, is_bot):
        if not isinstance(text, str) or not text.strip():
            return
        now = time.monotonic()
        with self.lock:
            self._roll_locked()
            self.entries.append((author, text))
            if len(self.entries) > self.limit:
                del self.entries[: len(self.entries) - self.limit]
            if is_bot:
                self.last_bot = now
            else:
                self.user_count += 1
                self.last_user = now

    def user_interactions(self):
        with self.lock:
            self._roll_locked()
            return self.user_count

    def gate_seconds(self):
        now = time.monotonic()
        with self.lock:
            self._roll_locked()
            since_bot = None if self.last_bot is None else now - self.last_bot
            since_user = None if self.last_user is None else now - self.last_user
            return since_bot, since_user

    def slice_blocks(self, first_messages, recent_messages):
        with self.lock:
            self._roll_locked()
            entries = list(self.entries)
        count = len(entries)
        if first_messages + recent_messages >= count:
            return entries, []
        head = entries[:first_messages] if first_messages > 0 else []
        tail = entries[count - recent_messages :] if recent_messages > 0 else []
        return head, tail


class HookState:
    def __init__(self, path):
        self.path = path
        self.lock = threading.Lock()
        stored = read_json_state(path)
        if not isinstance(stored, dict):
            stored = {}
        runs = stored.get("runs")
        self.runs = (
            {
                name: key
                for name, key in runs.items()
                if isinstance(name, str) and isinstance(key, str)
            }
            if isinstance(runs, dict)
            else {}
        )
        budget = stored.get("budget")
        if isinstance(budget, dict):
            date = budget.get("date")
            count = budget.get("count")
            self.budget_date = date if isinstance(date, str) else None
            self.budget_count = (
                count if isinstance(count, int) and not isinstance(count, bool) else 0
            )
        else:
            self.budget_date = None
            self.budget_count = 0
        last_fire = stored.get("last_fire")
        self.last_fire = (
            last_fire
            if isinstance(last_fire, (int, float)) and not isinstance(last_fire, bool)
            else 0.0
        )

    def _persist_locked(self):
        try:
            write_json_state(
                self.path,
                {
                    "runs": self.runs,
                    "budget": {"date": self.budget_date, "count": self.budget_count},
                    "last_fire": self.last_fire,
                },
            )
        except OSError as e:
            log_error(f"signal-bot: could not persist the hook state: {e}")

    def _roll_budget_locked(self, today):
        if self.budget_date != today:
            self.budget_date = today
            self.budget_count = 0

    def already_fired(self, name, window_key):
        with self.lock:
            return self.runs.get(name) == window_key

    def fired_today(self, name):
        today = today_string()
        with self.lock:
            return self.runs.get(name) == today

    def budget_remaining(self, limit):
        today = today_string()
        with self.lock:
            self._roll_budget_locked(today)
            return max(limit - self.budget_count, 0)

    def seconds_since_last_fire(self):
        with self.lock:
            if not self.last_fire:
                return None
            return max(0.0, time.time() - self.last_fire)

    def mark_fired(self, name, window_key):
        today = today_string()
        with self.lock:
            self._roll_budget_locked(today)
            snapshot = {
                "run": self.runs.get(name),
                "budget_date": self.budget_date,
                "budget_count": self.budget_count,
                "last_fire": self.last_fire,
            }
            self.runs[name] = window_key
            self.budget_count += 1
            self.last_fire = time.time()
            self._persist_locked()
            return snapshot

    def rollback_fire(self, name, snapshot):
        with self.lock:
            if snapshot["run"] is None:
                self.runs.pop(name, None)
            else:
                self.runs[name] = snapshot["run"]
            self.budget_date = snapshot["budget_date"]
            self.budget_count = snapshot["budget_count"]
            self.last_fire = snapshot["last_fire"]
            self._persist_locked()


def format_transcript_separator(template, separator):
    try:
        return template.format(separator=separator)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid hooks transcript separator template, using the marker as is",
            file=sys.stderr,
        )
        return separator


def render_hook_transcript(cfg, head, tail, separator, total_max, block_min):
    if not (head and tail):
        return render_recap(cfg, head + tail, total_max)
    joiner = "\n" + separator + "\n"
    body_max = max(total_max - len(joiner), 0)
    head_max = max(body_max // 2, block_min)
    head_text = render_recap(cfg, head, head_max, keep_newest=False)
    tail_max = max(body_max - len(head_text), block_min)
    tail_text = render_recap(cfg, tail, tail_max)
    return head_text + joiner + tail_text


def hook_prompt(template, system_instruction, instruction, transcript):
    values = {
        "systemInstruction": system_instruction,
        "instruction": instruction,
        "transcript": transcript,
    }
    try:
        return template.format(**values)
    except (KeyError, IndexError):
        print(
            "signal-bot: invalid hooks prompt template, using the default",
            file=sys.stderr,
        )
        return (
            f"{values['systemInstruction']}\n\n"
            f"{values['transcript']}\n\n{values['instruction']}"
        )


class HookScheduler:
    def __init__(self, cfg, hooks, hook_state, transcript, fire_fn):
        self.cfg = cfg
        self.hooks = hooks
        self.hook_state = hook_state
        self.transcript = transcript
        self.fire_fn = fire_fn
        self.max_sends = len(hooks) + cfg["additional_hook_sends_per_day"]
        self.min_between = cfg["min_seconds_between_hooks"]
        self.min_since_bot = cfg["min_seconds_since_bot_message"]
        self.min_since_user = cfg["min_seconds_since_user_message"]
        self.times = {
            name: (
                parse_hook_time(hook["start_time"]),
                parse_hook_time(hook["end_time"]),
            )
            for name, hook in hooks.items()
        }
        self.lock = threading.Lock()
        self.schedule = {}

    def _window_key(self, name, now):
        start_hm, end_hm = self.times[name]
        _, _, key, _ = current_window(now, start_hm, end_hm)
        return key

    def _roll(self, name, hook, now):
        start_hm, end_hm = self.times[name]
        open_epoch, close_epoch, key, _ = current_window(now, start_hm, end_hm)
        lo = max(now, open_epoch)
        window = f"{hook['start_time']}-{hook['end_time']}"
        fire_at = None
        if lo < close_epoch:
            roll = random.random()
            if roll < hook["probability"]:
                fire_at = random.uniform(lo, close_epoch)
            if fire_at is None:
                print(
                    f"signal-bot: hook {name!r} not scheduled for window {window}, "
                    f"roll {roll:.2f}/{hook['probability']}",
                    file=sys.stderr,
                )
            else:
                same_day = time.localtime(fire_at)[:3] == time.localtime(now)[:3]
                when_label = "today" if same_day else "tomorrow"
                print(
                    f"signal-bot: hook {name!r} scheduled for "
                    f"{time.strftime('%H:%M', time.localtime(fire_at))} ({when_label}) "
                    f"in window {window}, roll {roll:.2f}/{hook['probability']}",
                    file=sys.stderr,
                )
        entry = {"key": key, "close": close_epoch, "fire_at": fire_at, "done": False}
        return entry

    def _reschedule(self, entry, now):
        if now >= entry["close"]:
            return None
        return random.uniform(now, entry["close"])

    def _gates_pass(self, name, hook):
        if any(self.hook_state.fired_today(dep) for dep in hook["skip_if_fired_today"]):
            return False, "exclusion"
        if not all(
            self.hook_state.fired_today(dep) for dep in hook["run_only_if_fired_today"]
        ):
            return False, "prerequisite"
        if self.hook_state.budget_remaining(self.max_sends) <= 0:
            return False, "budget"
        since_fire = self.hook_state.seconds_since_last_fire()
        if since_fire is not None and since_fire < self.min_between:
            return False, "between"
        min_since_bot = hook["min_seconds_since_bot_message"]
        if min_since_bot is None:
            min_since_bot = self.min_since_bot
        min_since_user = hook["min_seconds_since_user_message"]
        if min_since_user is None:
            min_since_user = self.min_since_user
        since_bot, since_user = self.transcript.gate_seconds()
        if since_bot is not None and since_bot < min_since_bot:
            return False, "bot"
        if (
            min_since_user > 0
            and since_user is not None
            and since_user < min_since_user
        ):
            return False, "user"
        if self.transcript.user_interactions() < hook["min_user_interactions"]:
            return False, "activity"
        return True, "pass"

    def _apply_block(self, name, policy, now):
        with self.lock:
            entry = self.schedule[name]
            if policy == "skip":
                entry["done"] = True
                return
            if policy == "wait":
                if now >= entry["close"]:
                    entry["done"] = True
                else:
                    entry["fire_at"] = now
                return
            new_at = self._reschedule(entry, now)
            entry["fire_at"] = new_at
            entry["done"] = new_at is None

    def _tick(self):
        now = time.time()
        for name, hook in self.hooks.items():
            key = self._window_key(name, now)
            with self.lock:
                entry = self.schedule.get(name)
                if entry is None or entry["key"] != key:
                    entry = self._roll(name, hook, now)
                    self.schedule[name] = entry
                fire_at = entry["fire_at"]
                done = entry["done"]
            if fire_at is None or done or now < fire_at:
                continue
            if self.hook_state.already_fired(name, key):
                with self.lock:
                    self.schedule[name]["done"] = True
                continue
            passed, reason = self._gates_pass(name, hook)
            if not passed:
                policy = HOOK_BLOCK_POLICY.get(reason, hook["on_block"])
                with self.lock:
                    entry = self.schedule[name]
                    changed = entry.get("reason") != reason
                    entry["reason"] = reason
                if changed:
                    print(
                        f"signal-bot: hook {name!r} blocked by {reason}, applying "
                        f"{policy}",
                        file=sys.stderr,
                    )
                self._apply_block(name, policy, now)
                continue
            fired = self.fire_fn(name, hook, key)
            with self.lock:
                if fired:
                    self.schedule[name]["done"] = True
                else:
                    new_at = self._reschedule(self.schedule[name], now)
                    self.schedule[name]["fire_at"] = new_at
                    self.schedule[name]["done"] = new_at is None
        return self._next_sleep()

    def _next_sleep(self):
        now = time.time()
        with self.lock:
            upcoming = [
                entry["fire_at"] - now
                for entry in self.schedule.values()
                if entry["fire_at"] is not None
                and not entry["done"]
                and entry["fire_at"] > now
            ]
        return max(min([HOOK_POLL_SECONDS] + upcoming), HOOK_MIN_SLEEP_SECONDS)

    def run(self):
        while True:
            try:
                wait = self._tick()
            except Exception as e:
                print(
                    f"signal-bot: hook scheduler tick failed: {type(e).__name__}: {e}",
                    file=sys.stderr,
                )
                wait = HOOK_POLL_SECONDS
            time.sleep(wait)

    def describe(self, name):
        hook = self.hooks[name]
        window = f"{hook['start_time']}-{hook['end_time']}"
        key = self._window_key(name, time.time())
        if self.hook_state.already_fired(name, key):
            return message_text(self.cfg, "status_hook_fired").replace(
                "{window}", window
            )
        with self.lock:
            entry = self.schedule.get(name)
            scheduled = (
                entry["fire_at"]
                if entry and entry["key"] == key and not entry["done"]
                else None
            )
        if scheduled is not None:
            time_text = time.strftime("%H:%M", time.localtime(scheduled))
            if time.localtime(scheduled)[:3] != time.localtime()[:3]:
                time_text = f"{time_text} (tomorrow)"
            return (
                message_text(self.cfg, "status_hook_scheduled")
                .replace("{time}", time_text)
                .replace("{window}", window)
            )
        return message_text(self.cfg, "status_hook_idle").replace("{window}", window)


def serve(cfg):
    from flask import Flask, jsonify, request
    from waitress import serve as waitress_serve

    account = require_secret(cfg["account_file"], "phone number")
    contacts_by_name, contacts_by_number, _ = load_contacts(cfg, account)
    contact_numbers = set(contacts_by_number)
    allowed_uuids = AllowedUuids(cfg["recipients_file"], contact_numbers)
    api_token = require_secret(cfg["api_token_file"], "API token")
    ha_token = require_secret(cfg["ha_token_file"], "Home Assistant token")
    max_age_seconds = cfg["inbound_max_age_seconds"]
    quote_replies = cfg["quote_replies"]
    typing_delay_seconds = cfg["typing_indicator_delay_seconds"]
    group_filter = cfg["group_filter"]
    group_filter_enabled = bool(group_filter["enable"])
    group_filter_context_messages = group_filter["context_messages"]
    group_filter_silent = frozenset(
        answer.casefold() for answer in group_filter["silent_answers"]
    )
    group_filter_maybe = frozenset(
        answer.casefold() for answer in group_filter["maybe_answers"]
    )
    group_filter_maybe_probability = group_filter["maybe_probability"]
    group_filter_maybe_budget = MaybeBudget(
        group_filter["maybe_budget"], group_filter["maybe_budget_seconds"]
    )
    ha_session_seconds = cfg["ha_session_seconds"]
    context_max_chars = cfg["context_max_chars"]
    max_split_messages = cfg["max_split_messages"]
    instruction_template = cfg["instruction_template"]
    reactions_config = cfg["reactions"]
    reactions_enabled = bool(reactions_config["enable"])
    reaction_meanings = build_reaction_meanings(cfg)
    transcription_config = cfg["transcription"]
    transcription_enabled = bool(transcription_config["enable"])
    attachments_dir = transcription_config["attachments_dir"]
    hooks_config = {
        name: hook for name, hook in cfg["hooks"].items() if hook.get("enable")
    }
    hooks_active = bool(hooks_config)
    hooks_instruction = cfg["hooks_instruction"]
    hooks_prompt_template = cfg["hooks_prompt_template"]
    hooks_transcript_separator = format_transcript_separator(
        cfg["hooks_transcript_separator_template"], cfg["hooks_transcript_separator"]
    )
    hooks_context_max_chars = cfg["hooks_context_max_chars"]
    hooks_block_min_chars = cfg["hooks_block_min_chars"]
    ha_error_messages = {
        message_text(cfg, key)
        for key in (
            "ha_unreachable",
            "ha_unexpected_response",
            "ha_agent_failed",
            "ha_tool_call_artifact",
        )
    }
    bot_label = message_text(cfg, "quote_context_bot")
    daily_transcript = DailyTranscript(cfg["daily_transcript_limit"])
    hook_state = HookState(cfg["hook_state_file"]) if hooks_active else None
    scheduler = None
    group_id = read_group_id(cfg["group_id_file"])
    if group_id is None:
        print(
            "signal-bot: no persisted group id found, run bootstrap first",
            file=sys.stderr,
        )
        sys.exit(1)

    def current_group_id():
        return read_group_id(cfg["group_id_file"]) or group_id

    rpc = SignalRpc(cfg["socket_path"], account)
    sender = SendQueue(
        cfg["queue_max_depth"],
        cfg["max_sends_per_hour"],
        cfg["max_sends_per_minute"],
        cfg["send_state_file"],
    )
    inbound = Queue(maxsize=cfg["queue_max_depth"])
    commands = Queue(maxsize=cfg["queue_max_depth"])
    handled = HandledMessages(cfg["handled_file"], HANDLED_HISTORY_LIMIT)
    rejections = RejectionCounter(REJECT_LOG_INTERVAL_SECONDS)
    budget = SenderBudget(
        cfg["max_budget_per_sender_per_day"],
        SENDER_BUDGET_WINDOW_SECONDS,
        cfg["budget_input_chars"],
        cfg["budget_output_chars"],
        cfg["sender_budget_file"],
    )
    conversations = ConversationTracker(
        CONVERSATION_HISTORY_LIMIT,
        lambda: follow_up_window(cfg),
        cfg["context_max_messages"],
        reactions_config["target_max_messages"],
    )
    group_activity = GroupActivity()

    def send_chunk(params, quote):
        try:
            return rpc.call_checked("send", {**params, **quote} if quote else params)
        except RpcError as e:
            if not quote:
                raise
            print(
                f"signal-bot: quoted send failed, retrying without a quote: {e}",
                file=sys.stderr,
            )
            return rpc.call_checked("send", params)

    def do_send(job):
        (
            target,
            chunks,
            text_styles,
            quote,
            conversation_id,
            thread_key,
            notice,
            reactable,
        ) = job
        target_key = notice_key(target)
        notice_target = target_key if notice else None
        sent = 0
        reactable_timestamps = []
        reactable_text = ""
        for index, chunk in enumerate(chunks):
            if index:
                time.sleep(SEND_PACING_SECONDS)
                sender.wait_for_budget()
            params = {"message": chunk}
            params.update(target)
            if text_styles[index]:
                params["textStyle"] = text_styles[index]
            result = send_chunk(params, quote)
            sent += 1
            failures = describe_send_failures(result)
            if failures is not None:
                summary, retry_after = failures
                print(
                    f"signal-bot: signal-cli reported send failures: {summary}",
                    file=sys.stderr,
                )
                sender.defer(retry_after)
            if isinstance(result, dict):
                sent_timestamp = result.get("timestamp")
                conversations.remember_quote(
                    thread_key, sent_timestamp, conversation_id
                )
                conversations.remember_notice(
                    notice_target, sent_timestamp, chunk, index == 0
                )
                if sent_timestamp is not None:
                    reactable_timestamps.append(sent_timestamp)
                    if not reactable_text:
                        reactable_text = chunk
        if reactable:
            conversations.remember_reactable(
                target_key, reactable_timestamps, conversation_id, reactable_text
            )
        return sent

    def enqueue_send(
        target,
        text,
        conversation_id=None,
        quote=None,
        thread_key=None,
        ranges=None,
        notice=False,
        transcript_key=None,
        reactable=True,
        record_transcript=True,
    ):
        if not isinstance(text, str) or not text.strip():
            print(
                "signal-bot: nothing to send, skipping an empty message",
                file=sys.stderr,
            )
            return True
        if ranges is None:
            text, ranges = render_markdown(cfg, text)
        chunks = split_message(text, max_split_messages)
        styles = [
            chunk_text_styles(chunk, offset, span, ranges)
            for chunk, offset, span in chunks
        ]
        queued = sender.try_enqueue(
            (
                target,
                [chunk for chunk, _, _ in chunks],
                styles,
                quote,
                conversation_id,
                thread_key,
                notice,
                reactable and reactions_enabled,
            )
        )
        if queued and hooks_active and record_transcript and "groupId" in target:
            daily_transcript.record(bot_label, text, is_bot=True)
        if queued and transcript_key:
            conversations.remember_turn(
                transcript_key, message_text(cfg, "quote_context_bot"), text, True
            )
        return queued

    def send_typing(reply_target, stop=False):
        params = {**reply_target, "stop": True} if stop else reply_target
        try:
            rpc.call_checked("sendTyping", params)
        except Exception as e:
            action = "stop" if stop else "start"
            print(
                f"signal-bot: sendTyping {action} failed: {type(e).__name__}: {e}",
                file=sys.stderr,
            )

    @contextlib.contextmanager
    def typing_indicator(reply_target, delay=0.0):
        done = threading.Event()
        announced = threading.Event()

        def refresh():
            try:
                if delay and done.wait(delay):
                    return
                send_typing(reply_target)
                announced.set()
                wait = TYPING_REFRESH_SECONDS
                while not done.wait(wait):
                    started = time.monotonic()
                    send_typing(reply_target)
                    wait = max(
                        0.0, TYPING_REFRESH_SECONDS - (time.monotonic() - started)
                    )
            except Exception as e:
                print(
                    f"signal-bot: the typing indicator refresher stopped: "
                    f"{type(e).__name__}: {e}",
                    file=sys.stderr,
                )

        refresher = threading.Thread(target=refresh, daemon=True)
        refresher.start()
        try:
            yield
        finally:
            done.set()
            refresher.join(timeout=TYPING_REFRESH_SECONDS)
            if announced.is_set():
                send_typing(reply_target, stop=True)

    script_commands = cfg.get("script_commands") or {}
    script_shortcuts = {
        command["shortcut"]: name
        for name, command in script_commands.items()
        if command.get("shortcut")
    }

    def is_allowed(source_number, source_uuid):
        if source_number is not None and source_number in contact_numbers:
            return True
        return source_uuid is not None and allowed_uuids.holds(source_uuid)

    def budget_keys(number):
        return {number} | {
            uuid for uuid, value in allowed_uuids.numbers.items() if value == number
        }

    def budget_report():
        template = message_text(cfg, "status_budget_entry_template")
        return "\n".join(
            template.replace("{contact}", markdown_emphasis(cfg, name, "**"))
            .replace(
                "{used}",
                f"{sum(budget.used(key) for key in budget_keys(number)):.1f}",
            )
            .replace("{limit}", str(budget.limit))
            for name, number in sorted(contacts_by_name.items())
        )

    def claim_budget(budget_key, text, reply_target, reply_quote, thread_key):
        granted, first_rejection = budget.claim(budget_key, text)
        if granted:
            return True
        if first_rejection:
            print(
                "signal-bot: a sender reached the daily budget",
                file=sys.stderr,
            )
            enqueue_send(
                reply_target,
                message_text(cfg, "budget_exhausted"),
                quote=reply_quote,
                thread_key=thread_key,
            )
        return False

    def reaction_prompt_text(emoji, reacted_text, conversation_id, speaker_label=None):
        prompt = reaction_prompt(
            reactions_config["prompt_template"],
            wrap_instruction(instruction_template, reactions_config["instruction"]),
            emoji,
            reaction_meaning(reaction_meanings, reactions_config["fallback"], emoji),
        )
        if speaker_label:
            prompt = with_group_speaker(cfg, speaker_label, prompt)
        if conversation_id is None and reacted_text:
            prompt = with_quote_context(
                cfg, message_text(cfg, "quote_context_bot"), reacted_text, prompt
            )
        return prompt

    def reaction_reply(conversation_id, reacted_text, emoji, speaker_label=None):
        prompt = reaction_prompt_text(
            emoji, reacted_text, conversation_id, speaker_label
        )
        return call_ha_conversation(cfg, ha_token, prompt, conversation_id)

    def handle_reaction(envelope, data_message, reaction, source_number, source_uuid):
        if reaction.get("isRemove") or not reaction_targets_account(reaction, account):
            return
        timestamp = envelope.get("timestamp") or data_message.get("timestamp")
        if not is_fresh(timestamp, max_age_seconds):
            return

        sender_key = source_uuid or source_number
        sender_number = source_number or allowed_uuids.number_for(source_uuid)
        speaker_label = None
        group_info = data_message.get("groupInfo")
        if group_info:
            active_group_id = current_group_id()
            if group_info.get("groupId") != active_group_id:
                return
            reply_target = {"groupId": active_group_id}
            thread_key = f"group:{active_group_id}"
            target_keys = [thread_key]
            speaker_label = quote_author_label(
                cfg, contacts_by_number, account, sender_number
            )
        else:
            reply_target = {"recipient": [source_number or source_uuid]}
            thread_key = f"direct:{sender_key}"
            target_keys = [
                f"direct:{value}" for value in (sender_number, source_uuid) if value
            ]

        if not handled.claim(f"reaction:{sender_key}:{timestamp}"):
            print("signal-bot: ignoring a duplicate reaction", file=sys.stderr)
            return
        target_timestamp = reaction.get("targetSentTimestamp")
        claimed = conversations.claim_reactable(
            target_keys, target_timestamp, reactions_config["target_max_age_seconds"]
        )
        if claimed is None:
            return
        conversation_id, reacted_text, target_age = claimed

        if target_age > ha_session_seconds:
            conversation_id = None
        if conversation_id is None:
            conversation_id = conversations.resolve_thread(
                thread_key, ha_session_seconds
            )

        emoji = reaction.get("emoji")
        prompt = reaction_prompt_text(
            emoji, reacted_text, conversation_id, speaker_label
        )

        budget_key = sender_number or sender_key
        granted, _ = budget.claim(budget_key, prompt, notify=False)
        if not granted:
            print(
                "signal-bot: ignoring a reaction from a sender that reached the daily "
                "budget",
                file=sys.stderr,
            )
            return

        with typing_indicator(reply_target):
            reply_text, new_conversation_id = call_ha_conversation(
                cfg, ha_token, prompt, conversation_id
            )
        if new_conversation_id is not None:
            conversations.remember_thread(thread_key, new_conversation_id)
        if isinstance(reply_text, str):
            budget.charge(budget_key, reply_text)

        quote = (
            build_quote(target_timestamp, account, reacted_text)
            if quote_replies
            else None
        )
        if not enqueue_send(
            reply_target,
            reply_text,
            new_conversation_id,
            quote=quote,
            thread_key=thread_key,
            reactable=False,
        ):
            print(
                "signal-bot: reply queue full, dropping a reaction reply",
                file=sys.stderr,
            )

    def handle_receive(params):
        envelope = params.get("envelope", {})
        data_message = envelope.get("dataMessage")
        if not data_message:
            return
        attachments = [
            attachment
            for attachment in (data_message.get("attachments") or [])
            if isinstance(attachment, dict)
        ]

        def discard_all_attachments():
            for attachment in attachments:
                discard_attachment(attachments_dir, attachment)

        source_number = envelope.get("sourceNumber")
        source_uuid = envelope.get("sourceUuid")
        if not is_allowed(source_number, source_uuid):
            discard_all_attachments()
            return
        text = data_message.get("message")
        original_text = text
        quote_attachments = None
        timestamp = envelope.get("timestamp") or data_message.get("timestamp")
        sender_key = source_uuid or source_number
        message_key = f"{sender_key}:{timestamp}"
        claimed = False

        def claim_message():
            nonlocal claimed
            if not claimed:
                claimed = handled.claim(message_key)
            return claimed

        sender_number = source_number or allowed_uuids.number_for(source_uuid)
        budget_key = sender_number or sender_key
        sender_label = quote_author_label(
            cfg, contacts_by_number, account, sender_number
        )
        charged_key = None
        reply_quote = None
        quote_group_id = None
        quote_baseline = 0
        speaker_label = None
        group_info = data_message.get("groupInfo")
        if group_info:
            active_group_id = current_group_id()
            if group_info.get("groupId") != active_group_id:
                discard_all_attachments()
                return
            reply_target = {"groupId": active_group_id}
            thread_key = f"group:{active_group_id}"
            speaker_label = sender_label
            notice_keys = [f"group:{active_group_id}"]
        else:
            reply_target = {"recipient": [source_number or source_uuid]}
            thread_key = f"direct:{sender_key}"
            notice_keys = [
                f"direct:{value}" for value in (sender_number, source_uuid) if value
            ]

        transcribed = False
        transcription_failed = False
        if attachments:
            try:
                if not transcription_enabled:
                    return
                audio = select_audio_attachment(attachments)
                if audio is None:
                    if not text:
                        return
                elif not is_fresh(timestamp, max_age_seconds):
                    print(
                        f"signal-bot: ignoring a voice message older than {max_age_seconds}s",
                        file=sys.stderr,
                    )
                    return
                elif not claim_message():
                    print(
                        "signal-bot: ignoring a duplicate voice message",
                        file=sys.stderr,
                    )
                    return
                elif (
                    audio.get("size", 0) > transcription_config["max_attachment_bytes"]
                ):
                    print(
                        "signal-bot: rejecting a voice message above the size limit",
                        file=sys.stderr,
                    )
                    transcription_failed = True
                else:
                    source = attachment_file(attachments_dir, audio)
                    if source is None:
                        transcript = None
                    else:
                        with (
                            contextlib.nullcontext()
                            if group_info and group_filter_enabled
                            else typing_indicator(reply_target)
                        ):
                            transcript = transcribe_audio(transcription_config, source)
                    if transcript is None:
                        transcription_failed = True
                    else:
                        transcribed = True
                        quote_attachments = quote_attachment_specs(audio)
                        text = "\n".join(
                            part
                            for part in (transcript, audio.get("caption"), text)
                            if part
                        )
            finally:
                discard_all_attachments()

        if transcription_failed:
            if not enqueue_send(
                reply_target,
                transcription_config["failure_message"],
                None,
                thread_key=thread_key,
            ):
                print(
                    "signal-bot: reply queue full, dropping a transcription failure",
                    file=sys.stderr,
                )
            return

        if not text:
            reaction = data_message.get("reaction")
            if reactions_enabled and isinstance(reaction, dict):
                handle_reaction(
                    envelope, data_message, reaction, source_number, source_uuid
                )
            return

        if not is_fresh(timestamp, max_age_seconds):
            print(
                f"signal-bot: ignoring an inbound message older than {max_age_seconds}s",
                file=sys.stderr,
            )
            return

        message_is_builtin_command = (
            text.startswith("/") and split_command(text)[0] not in script_commands
        )

        if hooks_active and group_info and not message_is_builtin_command:
            daily_transcript.record(sender_label, text, is_bot=False)

        if transcribed or (group_info and quote_replies):
            reply_quote = build_quote(
                timestamp,
                sender_key,
                original_text if transcribed else text,
                quote_attachments,
            )
            if group_info:
                quote_group_id = active_group_id
                sequence = params.get(GROUP_SEQUENCE_KEY)
                quote_baseline = (
                    sequence
                    if isinstance(sequence, int)
                    else group_activity.count(active_group_id)
                )

        def current_quote():
            if reply_quote is None:
                return None
            if quote_group_id is None:
                return reply_quote
            if (
                not transcribed
                and group_activity.count(quote_group_id) == quote_baseline
            ):
                return None
            return reply_quote

        if not claim_message():
            print("signal-bot: ignoring a duplicate inbound message", file=sys.stderr)
            return

        conversation_id = None
        script_command = None
        command_name = ""
        command_argument = ""
        shortcut_problem = None
        if text.startswith("/"):
            command_name, command_argument = split_command(text)
            script_command = script_commands.get(command_name)
        else:
            shortcut_name = script_shortcuts.get(text[:1])
            if shortcut_name is not None:
                command_name = shortcut_name
                command_argument = text[1:].strip()
                script_command = script_commands[shortcut_name]
                if not command_argument[:1].isalnum():
                    shortcut_problem = command_message(
                        cfg, "script_shortcut_invalid", command_name
                    ).replace("{shortcut}", text[:1])
        if script_command is not None:
            if not claim_budget(
                budget_key, text, reply_target, current_quote(), thread_key
            ):
                return
            reply_text = shortcut_problem or script_argument_problem(
                cfg, command_name, script_command, command_argument
            )
            if reply_text is None:
                charged_key = budget_key
                print(
                    f"signal-bot: running the script command {command_name}",
                    file=sys.stderr,
                )
                with typing_indicator(reply_target):
                    reply_text = call_ha_script(
                        cfg, ha_token, command_name, script_command, command_argument
                    )
                conversations.remember_turn(
                    thread_key,
                    sender_label,
                    with_script_description(cfg, text, script_command),
                    True,
                )
                if isinstance(reply_text, str):
                    conversations.remember_turn(
                        thread_key,
                        message_text(cfg, "quote_context_bot"),
                        reply_text,
                        True,
                    )
        elif text.startswith("/"):

            def maybe_report():
                if not group_filter_enabled:
                    return message_text(cfg, "status_maybe_budget_disabled")
                return (
                    message_text(cfg, "status_maybe_budget_template")
                    .replace(
                        "{remaining}",
                        str(group_filter_maybe_budget.remaining(thread_key)),
                    )
                    .replace("{limit}", str(group_filter_maybe_budget.limit))
                )

            reply_text = handle_command(
                cfg, ha_token, account, text, budget_report, maybe_report, hooks_report
            )
        else:
            if not claim_budget(
                budget_key, text, reply_target, current_quote(), thread_key
            ):
                return
            charged_key = budget_key
            quote = data_message.get("quote")
            quote_id = quote.get("id") if isinstance(quote, dict) else None
            conversation_id = conversations.resolve_quote(thread_key, quote_id)
            reply_to_bot = quote_id is not None and (
                conversation_id is not None
                or conversations.notice_text(notice_keys, quote_id) is not None
                or (
                    isinstance(quote, dict)
                    and quote_author_label(
                        cfg,
                        contacts_by_number,
                        account,
                        quote.get("authorNumber")
                        or allowed_uuids.number_for(quote.get("authorUuid")),
                    )
                    == bot_label
                )
            )
            given_name = (cfg.get("profile_given_name") or "").strip()
            name_mentioned = bool(given_name) and (
                re.search(
                    r"(?<![a-zA-Z])" + re.escape(given_name) + r"(?![a-zA-Z])",
                    text,
                    re.IGNORECASE,
                )
                is not None
            )
            force_answer = reply_to_bot or name_mentioned
            quoted = None
            author = None
            if conversation_id is None and quote_id is not None:
                quoted = conversations.notice_text(notice_keys, quote_id)
                if quoted is not None:
                    author = message_text(cfg, "quote_context_bot")
                else:
                    quoted = quote.get("text")
                    author = quote_author_label(
                        cfg,
                        contacts_by_number,
                        account,
                        quote.get("authorNumber")
                        or allowed_uuids.number_for(quote.get("authorUuid")),
                    )
            recap = ""
            if conversation_id is None:
                conversation_id = conversations.resolve_thread(
                    thread_key, ha_session_seconds
                )
                if conversation_id is None or conversations.needs_recap(thread_key):
                    entries = conversations.transcript(thread_key)
                else:
                    entries = conversations.pending_turns(thread_key)
                recap = render_recap(cfg, entries, context_max_chars)
                if conversation_id is None and not recap and not quoted:
                    quoted = conversations.recent_notice(notice_keys)
                    author = message_text(cfg, "quote_context_bot")
            spoken = (
                transcription_prompt(
                    transcription_config["prompt_template"],
                    wrap_instruction(
                        instruction_template, transcription_config["instruction"]
                    ),
                    text,
                )
                if transcribed
                else text
            )
            prompt = (
                with_group_speaker(cfg, speaker_label, spoken)
                if speaker_label
                else spoken
            )
            print(
                "signal-bot: handling a "
                + ("group" if group_info else "direct")
                + " message",
                file=sys.stderr,
            )
            if group_info and group_filter_enabled and force_answer:
                print(
                    "signal-bot: forcing a group answer, reason "
                    + ("reply-to-bot" if reply_to_bot else "name-mention"),
                    file=sys.stderr,
                )
            if group_info and group_filter_enabled and not force_answer:
                filter_prompt = prompt
                if group_filter_context_messages:
                    filter_transcript = render_recap(
                        cfg,
                        conversations.transcript(thread_key)[
                            -group_filter_context_messages:
                        ],
                        context_max_chars,
                    )
                    if filter_transcript:
                        filter_prompt = group_filter_context(
                            group_filter["context_template"],
                            filter_transcript,
                            filter_prompt,
                        )
                verdict, _ = request_ha_conversation(
                    cfg,
                    ha_token,
                    group_filter_prompt(
                        group_filter["prompt_template"],
                        group_filter["instruction"],
                        filter_prompt,
                    ),
                    None,
                    group_filter["agent_id"],
                )
                decision = group_filter_verdict(
                    group_filter_silent, group_filter_maybe, verdict
                )
                detail = ""
                if decision == "maybe":
                    roll = random.random() * 100
                    roll_passed = roll < group_filter_maybe_probability
                    if not roll_passed:
                        decision = "maybe-silent"
                        reason = "roll"
                    elif group_filter_maybe_budget.allow(thread_key):
                        decision = "maybe-answer"
                        reason = "pass"
                    else:
                        decision = "maybe-silent"
                        reason = "budget"
                    detail = (
                        f", roll {roll:.1f}/{group_filter_maybe_probability}% "
                        f"reason {reason} budget "
                        f"{group_filter['maybe_budget']}/"
                        f"{group_filter['maybe_budget_seconds']}s"
                    )
                print(
                    "signal-bot: the group filter judged a group message, decision "
                    f"{decision}{detail}, verdict {verdict[:200]!r}",
                    file=sys.stderr,
                )
                if decision in ("silent", "maybe-silent"):
                    conversations.remember_turn(thread_key, sender_label, text)
                    return
            if quoted:
                prompt = with_quote_context(cfg, author, quoted, prompt)
            if recap:
                prompt = with_context_recap(cfg, recap, prompt)
            conversations.remember_turn(thread_key, sender_label, text)

            with typing_indicator(reply_target, typing_delay_seconds):
                reply_text, new_conversation_id = call_ha_conversation(
                    cfg, ha_token, prompt, conversation_id
                )
            drift = bool(
                conversation_id
                and new_conversation_id
                and new_conversation_id != conversation_id
            )
            if drift:
                print(
                    "signal-bot: Home Assistant replaced the conversation id, its "
                    "session had expired before the reply",
                    file=sys.stderr,
                )
            delivered = new_conversation_id is not None
            conversations.remember_thread(
                thread_key, new_conversation_id, bool(recap) and delivered, drift
            )
            if delivered and isinstance(reply_text, str):
                conversations.remember_turn(
                    thread_key, message_text(cfg, "quote_context_bot"), reply_text
                )
            if recap and delivered:
                budget.charge_context(charged_key, recap)
            conversation_id = new_conversation_id

        if charged_key is not None and isinstance(reply_text, str):
            budget.charge(charged_key, reply_text)

        if not enqueue_send(
            reply_target,
            reply_text,
            conversation_id,
            quote=current_quote(),
            thread_key=thread_key,
            record_transcript=not message_is_builtin_command,
        ):
            print("signal-bot: reply queue full, dropping reply", file=sys.stderr)

    def is_command_message(payload):
        data_message = payload.get("envelope", {}).get("dataMessage")
        if not isinstance(data_message, dict):
            return False
        if data_message.get("attachments"):
            return False
        text = data_message.get("message")
        if not isinstance(text, str) or not text.startswith("/"):
            return False
        name, _ = split_command(text)
        return name not in script_commands

    def dispatch_receive(params):
        payload = params.get("result")
        if not isinstance(payload, dict):
            payload = params
        envelope = payload.get("envelope")
        if not isinstance(envelope, dict):
            return
        if not isinstance(envelope.get("dataMessage"), dict):
            return
        group_info = envelope["dataMessage"].get("groupInfo")
        inbound_group_id = (
            group_info.get("groupId") if isinstance(group_info, dict) else None
        )
        is_reaction = not envelope["dataMessage"].get("message") and isinstance(
            envelope["dataMessage"].get("reaction"), dict
        )
        if (
            not is_reaction
            and inbound_group_id
            and inbound_group_id == current_group_id()
        ):
            payload[GROUP_SEQUENCE_KEY] = group_activity.note(inbound_group_id)
        if not is_allowed(envelope.get("sourceNumber"), envelope.get("sourceUuid")):
            rejections.record()
            return
        if is_command_message(payload):
            queue, label = commands, "command"
        else:
            queue, label = inbound, "inbound"
        try:
            queue.put_nowait(payload)
        except Full:
            print(
                f"signal-bot: {label} queue full, dropping message",
                file=sys.stderr,
            )

    def inbound_worker(queue, label):
        while True:
            params = queue.get()
            try:
                handle_receive(params)
            except Exception as e:
                print(
                    f"signal-bot: error handling {label} message: "
                    f"{type(e).__name__}: {e}",
                    file=sys.stderr,
                )

    def start_worker(queue, label):
        threading.Thread(
            target=inbound_worker, args=(queue, label), daemon=True
        ).start()

    def fire_hook(name, hook, window_key):
        head, tail = daily_transcript.slice_blocks(
            hook["context_first_messages"], hook["context_recent_messages"]
        )
        transcript_text = render_hook_transcript(
            cfg,
            head,
            tail,
            hooks_transcript_separator,
            hooks_context_max_chars,
            hooks_block_min_chars,
        )
        trigger = random.choice(hook["triggers"])
        static_message = trigger.get("message")
        if static_message is not None:
            print(f"signal-bot: firing hook {name!r}", file=sys.stderr)
            speech = static_message
        else:
            prompt = hook_prompt(
                hooks_prompt_template,
                hooks_instruction,
                trigger["instruction"],
                transcript_text,
            )
            print(f"signal-bot: firing hook {name!r}", file=sys.stderr)
            speech, new_conversation_id = call_ha_conversation(
                cfg, ha_token, prompt, None, hook["agent_id"]
            )
            if not isinstance(speech, str) or not speech.strip():
                print(
                    f"signal-bot: hook {name!r} got an empty reply from Home Assistant, "
                    "not sending",
                    file=sys.stderr,
                )
                return False
            errored = new_conversation_id is None or speech in ha_error_messages
            if errored and not hook["send_errors_into_chat"]:
                log_error(
                    f"signal-bot: hook {name!r} got an error reply from Home Assistant, "
                    f"skipping instead of posting it: {speech.strip()[:200]!r}"
                )
                return False
        title = (trigger.get("title") or "").strip()
        url = (trigger.get("url") or "").strip()
        text, ranges = format_outbound_text(cfg, title, speech.rstrip(), url)
        target = {"groupId": current_group_id()}
        reservation = hook_state.mark_fired(name, window_key)
        queued = enqueue_send(target, text, ranges=ranges, notice=True)
        if not queued:
            hook_state.rollback_fire(name, reservation)
            print(
                f"signal-bot: hook {name!r} send queue full, will retry",
                file=sys.stderr,
            )
        return queued

    def hooks_report():
        if not hooks_active:
            return message_text(cfg, "status_hooks_disabled")
        remaining = hook_state.budget_remaining(scheduler.max_sends)
        used = scheduler.max_sends - remaining
        entries = "\n".join(
            message_text(cfg, "status_hook_entry_template")
            .replace("{hook}", markdown_emphasis(cfg, name, "**"))
            .replace("{state}", scheduler.describe(name))
            for name in sorted(hooks_config)
        )
        return (
            message_text(cfg, "status_hooks_template")
            .replace("{used}", str(used))
            .replace("{limit}", str(scheduler.max_sends))
            .replace("{entries}", entries)
        )

    if hooks_active:
        scheduler = HookScheduler(
            cfg, hooks_config, hook_state, daily_transcript, fire_hook
        )

    rpc.on_receive = dispatch_receive
    rpc.start_reader()

    start_worker(inbound, "inbound")
    start_worker(commands, "command")
    threading.Thread(target=sender.run, args=(do_send,), daemon=True).start()
    if scheduler is not None:
        threading.Thread(target=scheduler.run, daemon=True).start()

    rpc.call_checked("subscribeReceive")

    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = MAX_REQUEST_BYTES
    expected_auth = f"Bearer {api_token}".encode()

    def authorized():
        header = request.headers.get("Authorization", "")
        return hmac.compare_digest(
            header.encode("utf-8", "surrogateescape"), expected_auth
        )

    @app.route("/v1/send", methods=["POST"])
    def http_send():
        if not authorized():
            return jsonify(error="unauthorized"), 401
        body = request.get_json(silent=True)
        if not isinstance(body, dict):
            return jsonify(error="request body must be a JSON object"), 400
        message = body.get("message")
        if not isinstance(message, str) or not message.strip():
            return jsonify(error="message must be a non empty string"), 400
        for name in ("title", "url"):
            value = body.get(name)
            if value is not None and not isinstance(value, str):
                return jsonify(error=f"{name} must be a string"), 400
        if body.get("channel") == "desktop":
            if desktop is None:
                return jsonify(error="the desktop chat channel is not enabled"), 400
            title = (body.get("title") or "").strip()
            url = (body.get("url") or "").strip()
            if not desktop.deliver(body.get("recipient"), message.rstrip(), title, url):
                return jsonify(error="unknown or unset desktop recipient"), 400
            return jsonify(status="delivered"), 202
        recipient = body.get("recipient")
        if recipient is not None:
            if not isinstance(recipient, str):
                return jsonify(error="recipient must be a string"), 400
            if recipient not in contacts_by_name:
                return (
                    jsonify(error="recipient must be a configured contact name"),
                    400,
                )
        context = body.get("context", True)
        if not isinstance(context, bool):
            return jsonify(error="context must be a boolean"), 400
        title = (body.get("title") or "").strip()
        url = (body.get("url") or "").strip()
        text, ranges = format_outbound_text(cfg, title, message.rstrip(), url)
        if recipient:
            number = contacts_by_name[recipient]
            target = {"recipient": [number]}
            transcript_key = f"direct:{allowed_uuids.uuid_for(number) or number}"
        else:
            group_id = current_group_id()
            target = {"groupId": group_id}
            transcript_key = f"group:{group_id}"
        if enqueue_send(
            target,
            text,
            ranges=ranges,
            notice=True,
            transcript_key=transcript_key if context else None,
        ):
            return jsonify(status="queued"), 202
        return jsonify(error="send queue is full"), 503

    desktop = None
    if bool(cfg.get("chat_enable")):
        import importlib.util
        import types as pytypes

        spec = importlib.util.spec_from_file_location(
            "desktop", cfg["desktop_module_file"]
        )
        desktop_mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(desktop_mod)

        def desktop_maybe_report():
            return message_text(cfg, "status_maybe_budget_disabled")

        def desktop_handle_command(text):
            return handle_command(
                cfg,
                ha_token,
                account,
                text,
                budget_report,
                desktop_maybe_report,
                hooks_report,
            )

        def desktop_call_ha(text, conversation_id):
            return call_ha_conversation(cfg, ha_token, text, conversation_id)

        def desktop_run_script(command_name, script_command, command_argument):
            problem = script_argument_problem(
                cfg, command_name, script_command, command_argument
            )
            if problem is not None:
                return problem
            print(
                f"signal-bot: running the desktop script command {command_name}",
                file=sys.stderr,
            )
            return call_ha_script(
                cfg, ha_token, command_name, script_command, command_argument
            )

        def desktop_command_reply(text):
            stripped = text.strip()
            if stripped.startswith("/"):
                command_name, command_argument = split_command(stripped)
                script_command = script_commands.get(command_name)
                if script_command is None:
                    return desktop_handle_command(stripped)
                return desktop_run_script(
                    command_name, script_command, command_argument
                )
            shortcut_name = script_shortcuts.get(stripped[:1]) if stripped else None
            if shortcut_name is None:
                return None
            command_argument = stripped[1:].strip()
            if not command_argument[:1].isalnum():
                return command_message(
                    cfg, "script_shortcut_invalid", shortcut_name
                ).replace("{shortcut}", stripped[:1])
            return desktop_run_script(
                shortcut_name, script_commands[shortcut_name], command_argument
            )

        desktop_recipients = cfg.get("chat_recipients") or {}

        def desktop_budget_key(user):
            for recipient_name, oauth_user in desktop_recipients.items():
                if oauth_user == user:
                    return contacts_by_name.get(recipient_name)
            return None

        brain = pytypes.SimpleNamespace(
            cfg=cfg,
            log_error=log_error,
            read_json_state=read_json_state,
            write_json_state=write_json_state,
            read_secret=read_secret,
            reactions_enabled=reactions_enabled,
            reactions_config=reactions_config,
            ha_session_seconds=ha_session_seconds,
            call_ha_conversation=desktop_call_ha,
            command_reply=desktop_command_reply,
            reaction_reply=reaction_reply,
            budget=budget,
            budget_key_for=desktop_budget_key,
            budget_exhausted=message_text(cfg, "budget_exhausted"),
        )
        desktop = desktop_mod.DesktopChannel(brain)
        desktop.register(app, jsonify, request)

    waitress_serve(app, host="127.0.0.1", port=cfg["api_port"], threads=4, ident=None)


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("bootstrap", "serve"):
        print("usage: bridge.py [bootstrap|serve] <config.json>", file=sys.stderr)
        sys.exit(1)
    cfg = load_config(sys.argv[2])
    if sys.argv[1] == "bootstrap":
        bootstrap(cfg)
    else:
        serve(cfg)


if __name__ == "__main__":
    main()
