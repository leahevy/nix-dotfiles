args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  mkQueueScripts =
    config:
    let
      mainUsername = self.host.mainUser.username;
      maxMessageLength = config.nx.linux.notifications.piper-tts.maxMessageLength;

      nxSpeak = pkgs.writeShellScriptBin "nx-speak" ''
        set -euo pipefail

        PRIORITY="normal"
        if [[ "''${1:-}" == "--priority" ]]; then
            if [[ $# -lt 3 ]]; then
                echo "Usage: nx-speak [--priority low|normal|high|critical] <text>" >&2
                exit 1
            fi
            PRIORITY="$2"
            shift 2
        fi

        if [[ "$PRIORITY" != "normal" && "$PRIORITY" != "low" && "$PRIORITY" != "high" && "$PRIORITY" != "critical" ]]; then
            echo "nx-speak: --priority must be 'low', 'normal', 'high' or 'critical'" >&2
            exit 1
        fi

        if [[ $# -lt 1 ]]; then
            echo "Usage: nx-speak [--priority low|normal|high|critical] <text>" >&2
            exit 1
        fi

        TEXT="$*"

        trim() {
            local var="$1"
            var="''${var#"''${var%%[![:space:]]*}"}"
            var="''${var%"''${var##*[![:space:]]}"}"
            printf '%s' "$var"
        }

        SANITIZED=$(${pkgs.coreutils}/bin/printf '%s' "$TEXT" | ${pkgs.gnused}/bin/sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g')
        SANITIZED=$(${pkgs.coreutils}/bin/printf '%s' "$SANITIZED" | ${pkgs.gnused}/bin/sed 's/—/-/g; s/–/-/g')
        SANITIZED=$(${pkgs.coreutils}/bin/printf '%s' "$SANITIZED" | ${pkgs.coreutils}/bin/tr -cd "A-Za-z0-9 \t\n.,!?':;%-")

        if [[ ''${#SANITIZED} -gt ${toString maxMessageLength} ]]; then
            SANITIZED="''${SANITIZED:0:${toString maxMessageLength}}"
        fi

        if [[ $EUID -eq 0 ]]; then
            TARGET_UID=$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg mainUsername})
            TARGET_GID=$(${pkgs.coreutils}/bin/id -g ${lib.escapeShellArg mainUsername})
            RUNTIME_DIR="/run/user/$TARGET_UID"
            QUEUE_DIR="$RUNTIME_DIR/nx-piper-tts/queue"
            if [[ ! -d "$QUEUE_DIR" ]]; then
                echo "nx-speak: queue directory not found, is piper-tts running?" >&2
                exit 1
            fi
        else
            RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$EUID}"
            QUEUE_DIR="$RUNTIME_DIR/nx-piper-tts/queue"
            ${pkgs.coreutils}/bin/mkdir -p -m 0700 "$QUEUE_DIR"
        fi

        TIMESTAMP=$(${pkgs.coreutils}/bin/date +%s%N)
        LINE_INDEX=0
        while IFS= read -r LINE || [[ -n "$LINE" ]]; do
            TRIMMED=$(trim "$LINE")
            if [[ -z "$TRIMMED" ]]; then
                continue
            fi

            LINE_INDEX=$((LINE_INDEX + 1))
            TMP_FILE=$(${pkgs.coreutils}/bin/mktemp --suffix=".''${PRIORITY}.tmp" "$QUEUE_DIR/''${TIMESTAMP}-$(${pkgs.coreutils}/bin/printf '%03d' "$LINE_INDEX")-XXXXXX")
            if [[ $EUID -eq 0 ]]; then
                ${pkgs.coreutils}/bin/chown "$TARGET_UID:$TARGET_GID" "$TMP_FILE"
            fi
            ${pkgs.coreutils}/bin/printf '%s' "$TRIMMED" > "$TMP_FILE"
            ${pkgs.coreutils}/bin/mv "$TMP_FILE" "''${TMP_FILE%.tmp}.msg"
        done <<< "$SANITIZED"
      '';

      nxSpeakFlush = pkgs.writeShellScriptBin "nx-speak-flush" ''
        set -euo pipefail

        if [[ $EUID -eq 0 ]]; then
            TARGET_UID=$(${pkgs.coreutils}/bin/id -u ${lib.escapeShellArg mainUsername})
            RUNTIME_DIR="/run/user/$TARGET_UID"
        else
            RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$EUID}"
        fi

        QUEUE_DIR="$RUNTIME_DIR/nx-piper-tts/queue"
        PID_FILE="$RUNTIME_DIR/nx-piper-tts/playing.pid"
        PIPER_PID_FILE="$RUNTIME_DIR/nx-piper-tts/piper.pid"

        if [[ -d "$QUEUE_DIR" ]]; then
            ${pkgs.coreutils}/bin/rm -f "$QUEUE_DIR"/*.msg
        fi

        if [[ -r "$PID_FILE" ]]; then
            PID=$(${pkgs.coreutils}/bin/cat "$PID_FILE")
            if [[ -n "$PID" ]]; then
                kill -TERM "$PID" 2>/dev/null || true
            fi
        fi

        if [[ -r "$PIPER_PID_FILE" ]]; then
            PIPER_PID=$(${pkgs.coreutils}/bin/cat "$PIPER_PID_FILE")
            if [[ -n "$PIPER_PID" ]]; then
                kill -9 "$PIPER_PID" 2>/dev/null || true
            fi
        fi
      '';
    in
    {
      inherit nxSpeak nxSpeakFlush;
    };
in
{
  name = "piper-tts";

  group = "notifications";
  input = "linux";

  description = "Background text-to-speech voice fed by a filesystem queue, spoken through PipeWire";

  submodules = {
    linux.sound.pipewire = true;
  };

  options = {
    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://huggingface.co/rhasspy/piper-voices";
      description = "Base repository URL under which language/model/quality voice files are hosted";
    };

    voiceModel = lib.mkOption {
      type = lib.types.submodule {
        options = {
          language = lib.mkOption {
            type = lib.types.str;
            description = "Piper voice language and locale, matching the rhasspy/piper-voices directory name";
          };
          model = lib.mkOption {
            type = lib.types.str;
            description = "Piper voice model name, matching the rhasspy/piper-voices directory name";
          };
          quality = lib.mkOption {
            type = lib.types.enum [
              "low"
              "medium"
              "high"
            ];
            description = "Piper voice quality tier";
          };
          revision = lib.mkOption {
            type = lib.types.str;
            description = "Full commit revision of the voice repository the files are fetched from";
          };
          onnxSha256 = lib.mkOption {
            type = lib.types.str;
            description = "sha256 hash of the onnx model file";
          };
          jsonSha256 = lib.mkOption {
            type = lib.types.str;
            description = "sha256 hash of the onnx.json config file";
          };
          speaker = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.unsigned;
            default = null;
            description = "Speaker ID for multi-speaker voice models, null uses the model default speaker";
          };
        };
      };
      default = {
        language = "en_GB";
        model = "alba";
        quality = "medium";
        revision = "ea046e8458f6acd997706d6e6066a022b42f6fb1";
        onnxSha256 = "0fyhdak36wagsvicsrk4qvfdn4888ijcii9jdkcgs28xm326j4s0";
        jsonSha256 = "1x49vmrqr4a5m5y5dasz4rgxdxmz5g3iykk9q8rddkpc08pmm5ma";
      };
      description = "Piper voice model source";
    };

    sink = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "headset"
          "speaker"
        ]
      );
      default = "speaker";
      description = "Preferred sink category for speech playback, resolved via linux.sound.pipewire sink IDs, null uses the system default sink";
    };

    volume = lib.mkOption {
      type = lib.types.numbers.between 0.0 1.0;
      default = 1.0;
      description = "Playback volume for synthesized speech from 0.0 to 1.0";
    };

    respectSessionLock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Delay normal-priority and drop low-priority queued speech while the session LockedHint is active, high and critical priority always speak immediately regardless of lock state, set to false to always speak immediately for all priorities";
    };

    nighttime = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Drop low, normal and high-priority queued speech during the configured nighttime window, critical priority always speaks immediately regardless, set to false to disable nighttime restrictions entirely";
          };
          start = lib.mkOption {
            type = lib.types.str;
            default = "22:00";
            description = "Time of day in HH:MM 24 hour format at which the nighttime window begins";
          };
          end = lib.mkOption {
            type = lib.types.str;
            default = "06:00";
            description = "Time of day in HH:MM 24 hour format at which the nighttime window ends";
          };
          volume = lib.mkOption {
            type = lib.types.numbers.between 0.0 1.0;
            default = 0.5;
            description = "Factor multiplied with the normal volume setting for critical-priority speech spoken during the nighttime window, only applied while nighttime restrictions are enabled";
          };
        };
      };
      default = { };
      description = "Nighttime quiet hours configuration for queued speech";
    };

    maxMessageLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Maximum characters kept per queued message after sanitization, longer messages are truncated";
    };

    minMessageGapSeconds = lib.mkOption {
      type = lib.types.numbers.nonnegative;
      default = 0.5;
      description = "Minimum seconds to sleep between two separate queued messages, not applied between lines split from the same nx-speak call";
    };

    maxMessageAgeSeconds = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 3600;
      description = "Maximum age in seconds a message may reach before it is dropped unspoken, counted from when it was queued or logged, critical priority always speaks regardless of age, null keeps messages until they are spoken";
    };

    script = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The nx-speak enqueue script derivation";
    };

    flushScript = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The nx-speak-flush script derivation";
    };

    speak = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.str);
      default = null;
      description = "Function taking { text, priority ? \"normal\", viaLog ? false } to generate a shell command that queues speech, viaLog routes through the journal for sandboxed contexts";
    };
  };

  module = {
    linux.init = config: {
      nx.linux.notifications.piper-tts.speak =
        {
          text,
          priority ? "normal",
          viaLog ? false,
        }:
        if !self.isEnabled then
          ":"
        else if viaLog then
          "${pkgs.systemd}/bin/systemd-cat -t nx-piper-tts-log -- ${pkgs.coreutils}/bin/echo ${
            lib.escapeShellArg (builtins.toJSON { inherit text priority; })
          } || true"
        else
          let
            script = config.nx.linux.notifications.piper-tts.script;
            scriptCmd = if script != null then "${script}/bin/nx-speak" else "nx-speak";
            priorityArg = lib.optionalString (
              priority != "normal"
            ) "--priority ${lib.escapeShellArg priority} ";
          in
          "${scriptCmd} ${priorityArg}${lib.escapeShellArg text} || true";
    };

    linux.enabled =
      config:
      let
        scripts = mkQueueScripts config;
      in
      {
        nx.linux.notifications.piper-tts.script = scripts.nxSpeak;
        nx.linux.notifications.piper-tts.flushScript = scripts.nxSpeakFlush;
        nx.packages.extra = [
          pkgs.piper-tts
          pkgs.pipewire
          pkgs.inotify-tools
        ];
      };

    linux.home =
      {
        config,
        baseUrl,
        voiceModel,
        sink,
        volume,
        respectSessionLock,
        minMessageGapSeconds,
        nighttime,
        maxMessageLength,
        maxMessageAgeSeconds,
        ...
      }:
      let
        pipewireCfg = config.nx.linux.sound.pipewire;
        resolvedSink =
          if sink == "headset" then
            pipewireCfg.headsetSinkID
          else if sink == "speaker" then
            pipewireCfg.speakerSinkID
          else
            null;

        langFamily = lib.head (lib.splitString "_" voiceModel.language);
        voiceFileBase = "${voiceModel.language}-${voiceModel.model}-${voiceModel.quality}";
        onnxUrl = "${baseUrl}/resolve/${voiceModel.revision}/${langFamily}/${voiceModel.language}/${voiceModel.model}/${voiceModel.quality}/${voiceFileBase}.onnx";
        jsonUrl = "${onnxUrl}.json";

        onnxFile = pkgs.fetchurl {
          url = onnxUrl;
          sha256 = voiceModel.onnxSha256;
        };
        jsonFile = pkgs.fetchurl {
          url = jsonUrl;
          sha256 = voiceModel.jsonSha256;
        };

        voiceDir = pkgs.runCommand "piper-voice-${voiceFileBase}" { } ''
          mkdir -p "$out"
          ln -s ${onnxFile} "$out/${voiceFileBase}.onnx"
          ln -s ${jsonFile} "$out/${voiceFileBase}.onnx.json"
        '';
        modelPath = "${voiceDir}/${voiceFileBase}.onnx";

        nxPiperVoiceHash = pkgs.writeShellScriptBin "nx-piper-voice-hash" ''
          set -euo pipefail

          if [[ $# -lt 3 || $# -gt 4 ]]; then
              echo "Usage: nx-piper-voice-hash <language> <model> <quality> [revision]" >&2
              echo "Example: nx-piper-voice-hash en_GB alba medium" >&2
              echo "Without a revision the current head revision is resolved and pinned." >&2
              exit 1
          fi

          LANGUAGE="$1"
          MODEL="$2"
          QUALITY="$3"
          REVISION="''${4:-}"
          BASE_URL="${baseUrl}"

          if [[ -z "$REVISION" ]]; then
              case "$BASE_URL" in
                  https://huggingface.co/*)
                      REPO_ID="''${BASE_URL#https://huggingface.co/}"
                      ;;
                  *)
                      echo "Cannot resolve a head revision for $BASE_URL, pass one explicitly!" >&2
                      exit 1
                      ;;
              esac
              REVISION=$(${helpers.packageFile args pkgs.curl "bin/curl"} -fsSL \
                  "https://huggingface.co/api/models/''${REPO_ID}" \
                  | ${helpers.packageFile args pkgs.jq "bin/jq"} -r '.sha')
          fi

          if [[ -z "$REVISION" || "$REVISION" == "null" ]]; then
              echo "Failed to resolve a revision for $BASE_URL!" >&2
              exit 1
          fi

          LANG_FAMILY="''${LANGUAGE%%_*}"
          FILE_BASE="''${LANGUAGE}-''${MODEL}-''${QUALITY}"
          ONNX_URL="${baseUrl}/resolve/''${REVISION}/''${LANG_FAMILY}/''${LANGUAGE}/''${MODEL}/''${QUALITY}/''${FILE_BASE}.onnx"
          JSON_URL="''${ONNX_URL}.json"

          ONNX_SHA256=$(${pkgs.nix}/bin/nix-prefetch-url "$ONNX_URL" 2>/dev/null | ${pkgs.coreutils}/bin/tail -n1)
          JSON_SHA256=$(${pkgs.nix}/bin/nix-prefetch-url "$JSON_URL" 2>/dev/null | ${pkgs.coreutils}/bin/tail -n1)

          ${pkgs.coreutils}/bin/cat <<VOICEEOF
          voiceModel = {
            language = "$LANGUAGE";
            model = "$MODEL";
            quality = "$QUALITY";
            revision = "$REVISION";
            onnxSha256 = "$ONNX_SHA256";
            jsonSha256 = "$JSON_SHA256";
          };
          VOICEEOF
        '';

        workerScript = pkgs.writers.writePython3 "nx-piper-tts-worker" { flakeIgnore = [ "E501" ]; } ''
          import fcntl
          import json
          import logging
          import os
          import queue
          import re
          import subprocess
          import threading
          import time
          import uuid
          from datetime import datetime

          logging.basicConfig(level=logging.INFO, format="nx-piper-tts-worker: %(message)s")
          log = logging.getLogger("nx-piper-tts-worker")

          PIPER_BIN = "${pkgs.piper-tts}/bin/piper"
          PW_PLAY_BIN = "${pkgs.pipewire}/bin/pw-play"
          INOTIFYWAIT_BIN = "${pkgs.inotify-tools}/bin/inotifywait"
          LOGINCTL_BIN = "${pkgs.systemd}/bin/loginctl"
          JOURNALCTL_BIN = "${pkgs.systemd}/bin/journalctl"
          LOG_TAG = "nx-piper-tts-log"

          MODEL_PATH = "${modelPath}"
          CONFIG_PATH = "${jsonFile}"
          SPEAKER = ${if voiceModel.speaker != null then toString voiceModel.speaker else "None"}
          TARGET_SINK = ${if resolvedSink != null then builtins.toJSON resolvedSink else "None"}
          VOLUME = ${toString volume}
          MAX_MESSAGE_LENGTH = ${toString maxMessageLength}

          RESPECT_SESSION_LOCK = ${if respectSessionLock then "True" else "False"}
          NIGHTTIME_ENABLE = ${if nighttime.enable then "True" else "False"}
          NIGHTTIME_START = "${nighttime.start}"
          NIGHTTIME_END = "${nighttime.end}"
          NIGHTTIME_VOLUME = ${toString nighttime.volume}
          MIN_MESSAGE_GAP_SECONDS = ${toString minMessageGapSeconds}
          MAX_MESSAGE_AGE_SECONDS = ${
            if maxMessageAgeSeconds != null then toString maxMessageAgeSeconds else "None"
          }

          RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.geteuid()}"
          BASE_DIR = os.path.join(RUNTIME_DIR, "nx-piper-tts")
          QUEUE_DIR = os.path.join(BASE_DIR, "queue")
          LOCK_FILE = os.path.join(BASE_DIR, "worker.lock")
          PID_FILE = os.path.join(BASE_DIR, "playing.pid")
          PIPER_PID_FILE = os.path.join(BASE_DIR, "piper.pid")
          PIPER_OUT_DIR = os.path.join(BASE_DIR, "piper-out")
          JOURNAL_CURSOR_FILE = os.path.join(BASE_DIR, "journal-cursor")

          ANSI_RE = re.compile(r"\x1b\[[0-9;]*[a-zA-Z]")
          DISALLOWED_RE = re.compile(r"[^A-Za-z0-9 \t.,!?':;%-]")

          piper_proc = None
          last_msg_timestamp = None


          def is_locked():
              try:
                  sessions = subprocess.run(
                      [LOGINCTL_BIN, "show-user", str(os.getuid()), "-p", "Sessions", "--value"],
                      capture_output=True, text=True,
                  ).stdout.split()
              except OSError:
                  return False
              for session in sessions:
                  hint = subprocess.run(
                      [LOGINCTL_BIN, "show-session", session, "-p", "LockedHint", "--value"],
                      capture_output=True, text=True,
                  ).stdout.strip()
                  if hint == "yes":
                      return True
              return False


          def is_nighttime():
              now = datetime.now().strftime("%H:%M")
              if NIGHTTIME_START < NIGHTTIME_END:
                  return NIGHTTIME_START <= now < NIGHTTIME_END
              return now >= NIGHTTIME_START or now < NIGHTTIME_END


          def start_piper():
              global piper_proc
              if piper_proc is not None and piper_proc.poll() is None:
                  return
              cmd = [PIPER_BIN, "-m", MODEL_PATH, "-c", CONFIG_PATH]
              if SPEAKER is not None:
                  cmd += ["--speaker", str(SPEAKER)]
              cmd += ["--output_dir", PIPER_OUT_DIR]
              piper_proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
              with open(PIPER_PID_FILE, "w") as f:
                  f.write(f"{piper_proc.pid}\n")


          def respawn_piper():
              global piper_proc
              if piper_proc is not None:
                  try:
                      piper_proc.kill()
                  except ProcessLookupError:
                      pass
                  try:
                      piper_proc.stdin.close()
                  except OSError:
                      pass
                  piper_proc.wait()
              piper_proc = None
              start_piper()


          def wait_for_wav(timeout):
              proc = subprocess.Popen(
                  [INOTIFYWAIT_BIN, "-q", "-e", "close_write", "--format", "%f", PIPER_OUT_DIR],
                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
              )
              deadline = time.monotonic() + timeout
              while time.monotonic() < deadline:
                  if proc.poll() is not None:
                      return "wav", (proc.stdout.readline().strip() or None)
                  if piper_proc.poll() is not None:
                      proc.kill()
                      proc.wait()
                      return "piper_died", None
                  time.sleep(0.05)
              proc.kill()
              proc.wait()
              return "timeout", None


          def safe_remove(path):
              try:
                  os.remove(path)
              except FileNotFoundError:
                  pass


          def priority_of_file(name):
              without_msg = name[:-4] if name.endswith(".msg") else name
              priority = without_msg.rsplit(".", 1)[-1]
              return priority if priority in ("low", "high", "critical") else "normal"


          def queued_at(path):
              stamp = os.path.basename(path).split("-", 1)[0]
              try:
                  return int(stamp) / 1000000000
              except ValueError:
                  pass
              try:
                  return os.path.getmtime(path)
              except OSError:
                  return time.time()


          def expired_age(queued):
              if MAX_MESSAGE_AGE_SECONDS is None:
                  return None
              age = time.time() - queued
              return age if age > MAX_MESSAGE_AGE_SECONDS else None


          def process_pending_bypass_priority():
              for f in sorted(os.listdir(QUEUE_DIR)):
                  if f.endswith(".msg") and priority_of_file(f) in ("high", "critical"):
                      process_one(os.path.join(QUEUE_DIR, f))


          def process_one(path):
              global last_msg_timestamp

              base = os.path.basename(path)
              priority = priority_of_file(base)

              def nighttime_drop():
                  return NIGHTTIME_ENABLE and priority != "critical" and is_nighttime()

              def expiry_drop():
                  if priority == "critical":
                      return False
                  age = expired_age(queued_at(path))
                  if age is None:
                      return False
                  log.info("dropping message older than %ss (age %ds): %s", MAX_MESSAGE_AGE_SECONDS, age, path)
                  safe_remove(path)
                  return True

              if expiry_drop():
                  return

              if nighttime_drop():
                  log.info("dropping message during nighttime: %s", path)
                  safe_remove(path)
                  return

              if RESPECT_SESSION_LOCK and priority not in ("high", "critical") and is_locked():
                  if priority == "low":
                      log.info("dropping low-priority message while session locked: %s", path)
                      safe_remove(path)
                      return
                  log.info("delaying message while session locked: %s", path)
                  while is_locked():
                      if expiry_drop():
                          return
                      if nighttime_drop():
                          log.info("dropping message: nighttime started while waiting for session unlock: %s", path)
                          safe_remove(path)
                          return
                      process_pending_bypass_priority()
                      time.sleep(1)

              try:
                  with open(path) as f:
                      text = f.read().replace("\n", " ")
              except FileNotFoundError:
                  log.info("message already flushed away: %s", path)
                  return

              msg_timestamp = base.split("-", 1)[0]
              if MIN_MESSAGE_GAP_SECONDS > 0:
                  if last_msg_timestamp is not None and msg_timestamp != last_msg_timestamp:
                      time.sleep(MIN_MESSAGE_GAP_SECONDS)
              last_msg_timestamp = msg_timestamp

              start_piper()

              try:
                  piper_proc.stdin.write((text + "\n").encode())
                  piper_proc.stdin.flush()
              except (BrokenPipeError, OSError):
                  pass

              kind, wav_name = wait_for_wav(30)

              if kind == "piper_died":
                  log.warning("piper exited before finishing synthesis for %s, respawning", path)
                  safe_remove(path)
                  respawn_piper()
                  return

              if kind == "timeout":
                  log.warning("synthesis timed out for %s, killing stuck piper, respawning", path)
                  safe_remove(path)
                  respawn_piper()
                  return

              if not wav_name:
                  log.warning("inotifywait produced no filename for %s", path)
                  safe_remove(path)
                  return

              wav = os.path.join(PIPER_OUT_DIR, wav_name)
              if not os.path.isfile(wav):
                  log.warning("expected output file missing for %s, wav_name=%r wav=%s", path, wav_name, wav)
                  safe_remove(path)
                  return

              effective_volume = VOLUME
              if NIGHTTIME_ENABLE and priority == "critical" and is_nighttime():
                  effective_volume = VOLUME * NIGHTTIME_VOLUME

              cmd = [PW_PLAY_BIN, "--volume", str(effective_volume)]
              if TARGET_SINK:
                  cmd += ["--target", TARGET_SINK]
              cmd.append(wav)
              play_proc = subprocess.Popen(cmd)
              with open(PID_FILE, "w") as f:
                  f.write(f"{play_proc.pid}\n")
              play_proc.wait()
              for p in (PID_FILE, wav, path):
                  try:
                      os.remove(p)
                  except FileNotFoundError:
                      pass


          def drain():
              while True:
                  files = sorted(f for f in os.listdir(QUEUE_DIR) if f.endswith(".msg"))
                  if not files:
                      break
                  for f in files:
                      process_one(os.path.join(QUEUE_DIR, f))


          def watch_queue(event_queue):
              proc = subprocess.Popen(
                  [INOTIFYWAIT_BIN, "-m", "-q", "-e", "create", "-e", "moved_to", "--format", "%f", QUEUE_DIR],
                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
              )
              for line in proc.stdout:
                  event_queue.put(line)


          def sanitize_text(text):
              text = ANSI_RE.sub("", text)
              text = text.replace("—", "-").replace("–", "-")
              text = DISALLOWED_RE.sub("", text)
              text = text.strip()
              return text[:MAX_MESSAGE_LENGTH]


          def enqueue_message(text, priority, timestamp_ns):
              if priority not in ("low", "high", "critical"):
                  priority = "normal"
              if priority != "critical" and expired_age(timestamp_ns / 1000000000) is not None:
                  return
              text = sanitize_text(text)
              if not text:
                  return
              name = f"{timestamp_ns}-000-{uuid.uuid4().hex[:6]}.{priority}"
              tmp_path = os.path.join(QUEUE_DIR, f"{name}.tmp")
              with open(tmp_path, "w") as f:
                  f.write(text)
              os.rename(tmp_path, os.path.join(QUEUE_DIR, f"{name}.msg"))


          def watch_log():
              proc = subprocess.Popen(
                  [JOURNALCTL_BIN, "-t", LOG_TAG, "-f", "--output=json", "--cursor-file", JOURNAL_CURSOR_FILE],
                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
              )
              for line in proc.stdout:
                  try:
                      entry = json.loads(line)
                      timestamp_ns = int(entry["__REALTIME_TIMESTAMP"]) * 1000
                      payload = json.loads(entry["MESSAGE"])
                      text = payload["text"]
                      priority = payload.get("priority", "normal")
                      if not isinstance(text, str) or not isinstance(priority, str):
                          continue
                      enqueue_message(text, priority, timestamp_ns)
                  except (ValueError, KeyError, TypeError):
                      continue


          def main():
              os.makedirs(BASE_DIR, mode=0o700, exist_ok=True)

              lock_fd = os.open(LOCK_FILE, os.O_CREAT | os.O_RDWR, 0o600)
              fcntl.flock(lock_fd, fcntl.LOCK_EX)

              os.makedirs(QUEUE_DIR, mode=0o700, exist_ok=True)
              os.makedirs(PIPER_OUT_DIR, mode=0o700, exist_ok=True)
              for f in os.listdir(PIPER_OUT_DIR):
                  if f.endswith(".wav"):
                      os.remove(os.path.join(PIPER_OUT_DIR, f))

              event_queue = queue.Queue()
              threading.Thread(target=watch_queue, args=(event_queue,), daemon=True).start()
              threading.Thread(target=watch_log, daemon=True).start()

              start_piper()

              while True:
                  drain()
                  try:
                      event_queue.get(timeout=30)
                  except queue.Empty:
                      pass


          if __name__ == "__main__":
              main()
        '';
      in
      {
        assertions = [
          {
            assertion = builtins.match "^([01][0-9]|2[0-3]):[0-5][0-9]$" nighttime.start != null;
            message = "nx.linux.notifications.piper-tts.nighttime.start must be in HH:MM 24 hour format!";
          }
          {
            assertion = builtins.match "^([01][0-9]|2[0-3]):[0-5][0-9]$" nighttime.end != null;
            message = "nx.linux.notifications.piper-tts.nighttime.end must be in HH:MM 24 hour format!";
          }
          {
            assertion = !nighttime.enable || nighttime.start != nighttime.end;
            message = "nx.linux.notifications.piper-tts.nighttime.start and nighttime.end must differ when nighttime is enabled!";
          }
        ];

        home.packages = [
          config.nx.linux.notifications.piper-tts.script
          config.nx.linux.notifications.piper-tts.flushScript
          nxPiperVoiceHash
        ];

        systemd.user.services.nx-piper-tts-worker = {
          Unit = {
            Description = "NX Piper TTS Queue Worker";
          };
          Service = {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = "5";
            ExecStart = "${workerScript}";
          };
        };

        systemd.user.timers.nx-piper-tts-worker-startup = {
          Unit = {
            Description = "Start NX Piper TTS Queue Worker";
            After = [ "graphical-session.target" ];
          };
          Timer = {
            OnActiveSec = "10s";
            Unit = "nx-piper-tts-worker-startup.service";
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };

        systemd.user.services.nx-piper-tts-worker-startup = {
          Unit = {
            Description = "Start NX Piper TTS Queue Worker";
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/systemctl --user start nx-piper-tts-worker.service";
            RemainAfterExit = true;
          };
        };
      };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+Q" = {
              action = spawn-sh "${(mkQueueScripts config).nxSpeakFlush}/bin/nx-speak-flush";
              hotkey-overlay.title = "System:Interrupt queued speech";
            };
          };
        };
      };
    };

    linux.system =
      { config, ... }:
      {
        environment.systemPackages = [
          config.nx.linux.notifications.piper-tts.script
          config.nx.linux.notifications.piper-tts.flushScript
        ];
      };
  };
}
