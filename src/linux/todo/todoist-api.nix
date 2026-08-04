args@{
  lib,
  pkgs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "todoist-api";
  group = "todo";
  input = "linux";
  description = "Programmatic Todoist task creation with a retrying queue";

  options = {
    defaultProjectId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default Todoist project ID new tasks are created in when a task does not specify one, left unset to fall back to the Todoist Inbox.";
    };

    defaultSectionId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default Todoist section ID new tasks are created in when a task does not specify one.";
    };

    knownAssignees = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Known Todoist assignees, mapping a short name to their Todoist user ID.";
    };

    defaultAssignee = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default assignee name new tasks are assigned to when a task does not specify one, must be a key in knownAssignees.";
    };

    apiEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://api.todoist.com/api/v1/tasks";
      description = "Todoist API endpoint used to create tasks. Uses the unified API v1.";
    };

    drainInterval = lib.mkOption {
      type = lib.types.str;
      default = "5m";
      description = "Interval between queue drain attempts, passed to systemd OnUnitInactiveSec.";
    };

    drainRandomDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "RandomizedDelaySec for the queue drain timer in seconds.";
    };

    stuckThresholdSec = lib.mkOption {
      type = lib.types.int;
      default = 21600;
      description = "Age in seconds after which a queued task still failing to create triggers a one-time Pushover escalation.";
    };

    queueScript = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The todoist-queue-task script derivation (set in system namespace).";
    };

    queueTask = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.str);
      default = null;
      description = "Function returning a shell command string that enqueues a Todoist task for creation.";
    };
  };

  module =
    let
      queueTaskScript =
        config:
        let
          defaultProjectId = config.nx.linux.todo.todoist-api.defaultProjectId;
          defaultSectionId = config.nx.linux.todo.todoist-api.defaultSectionId;
          defaultAssignee = config.nx.linux.todo.todoist-api.defaultAssignee;
          knownAssignees = config.nx.linux.todo.todoist-api.knownAssignees;
          defaultAssigneeId =
            if defaultAssignee == null then null else knownAssignees.${defaultAssignee} or null;
          shellDefault = value: lib.escapeShellArg (if value == null then "" else value);
        in
        pkgs.writeShellScriptBin "todoist-queue-task" ''
          set -euo pipefail

          DEFAULT_PROJECT_ID=${shellDefault defaultProjectId}
          DEFAULT_SECTION_ID=${shellDefault defaultSectionId}
          DEFAULT_ASSIGNEE_ID=${shellDefault defaultAssigneeId}

          STATE_DIR="/var/lib/nx-todoist-api"
          QUEUE_DIR="$STATE_DIR/queue"
          MARKER_DIR="$STATE_DIR/state"

          show_usage() {
            echo "Usage: $0 --topic <topic> --content <content> [--description <description>] [--project-id <id>] [--section-id <id>] [--assignee-id <id>] [--due-string <text>] [--label <label>]... [--priority <1-4>]" >&2
          }

          TOPIC=""
          CONTENT=""
          DESCRIPTION=""
          PROJECT_ID=""
          SECTION_ID=""
          ASSIGNEE_ID=""
          DUE_STRING=""
          PRIORITY=""
          LABELS=()

          while [[ $# -gt 0 ]]; do
            case $1 in
              --topic)
                TOPIC="$2"
                shift 2
                ;;
              --content)
                CONTENT="$2"
                shift 2
                ;;
              --description)
                DESCRIPTION="$2"
                shift 2
                ;;
              --project-id)
                PROJECT_ID="$2"
                shift 2
                ;;
              --section-id)
                SECTION_ID="$2"
                shift 2
                ;;
              --assignee-id)
                ASSIGNEE_ID="$2"
                shift 2
                ;;
              --due-string)
                DUE_STRING="$2"
                shift 2
                ;;
              --label)
                LABELS+=("$2")
                shift 2
                ;;
              --priority)
                PRIORITY="$2"
                shift 2
                ;;
              -h|--help)
                show_usage
                exit 0
                ;;
              *)
                echo "Unknown option: $1" >&2
                show_usage
                exit 1
                ;;
            esac
          done

          if [[ -z "$TOPIC" || -z "$CONTENT" ]]; then
            echo "Error: --topic and --content are required" >&2
            show_usage
            exit 1
          fi

          SAFE_TOPIC=$(printf '%s' "$TOPIC" | ${pkgs.coreutils}/bin/tr -c 'a-zA-Z0-9-' '-')
          MARKER_FILE="$MARKER_DIR/$SAFE_TOPIC.last-queued"
          QUEUE_FILE="$QUEUE_DIR/$SAFE_TOPIC.json"
          TODAY=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)

          if [[ -f "$MARKER_FILE" ]] && [[ "$(${pkgs.coreutils}/bin/cat "$MARKER_FILE" 2>/dev/null || true)" == "$TODAY" ]]; then
            exit 0
          fi

          if [[ -z "$DUE_STRING" ]]; then
            DUE_STRING="today"
          fi

          if [[ -z "$PROJECT_ID" ]]; then
            PROJECT_ID="$DEFAULT_PROJECT_ID"
          fi

          if [[ -z "$SECTION_ID" ]]; then
            SECTION_ID="$DEFAULT_SECTION_ID"
          fi

          if [[ -z "$ASSIGNEE_ID" ]]; then
            ASSIGNEE_ID="$DEFAULT_ASSIGNEE_ID"
          fi

          TMP_FILE=$(${pkgs.coreutils}/bin/mktemp "$QUEUE_DIR/.$SAFE_TOPIC.XXXXXX")
          trap '${pkgs.coreutils}/bin/rm -f "$TMP_FILE"' EXIT
          ${pkgs.coreutils}/bin/chmod 640 "$TMP_FILE"

          ${pkgs.jq}/bin/jq -n \
            --arg content "$CONTENT" \
            --arg description "$DESCRIPTION" \
            --arg project_id "$PROJECT_ID" \
            --arg section_id "$SECTION_ID" \
            --arg assignee_id "$ASSIGNEE_ID" \
            --arg due_string "$DUE_STRING" \
            --argjson priority "''${PRIORITY:-null}" \
            --argjson labels "$(printf '%s\n' "''${LABELS[@]}" | ${pkgs.jq}/bin/jq -R . | ${pkgs.jq}/bin/jq -s 'map(select(length > 0))')" \
            '{content: $content}
             + (if $description != "" then {description: $description} else {} end)
             + (if $project_id != "" then {project_id: $project_id} else {} end)
             + (if $section_id != "" then {section_id: $section_id} else {} end)
             + (if $assignee_id != "" then {assignee_id: $assignee_id} else {} end)
             + (if $due_string != "" then {due_string: $due_string, due_lang: "en"} else {} end)
             + (if $priority != null then {priority: $priority} else {} end)
             + (if ($labels | length) > 0 then {labels: $labels} else {} end)
            ' > "$TMP_FILE"

          ${pkgs.coreutils}/bin/mv -f "$TMP_FILE" "$QUEUE_FILE"
          printf '%s\n' "$TODAY" > "$MARKER_FILE"
        '';

      queryApiScript =
        let
          hostname = self.host.hostname;
        in
        pkgs.writeShellScriptBin "todoist-query-api" ''
          set -euo pipefail

          if [[ "$EUID" -ne 0 ]]; then
            printf 'Must be run as root!\n' >&2
            exit 1
          fi

          if [[ "$#" -lt 2 ]]; then
            printf 'Usage: todoist-query-api METHOD API_PATH [curl args...]\n' >&2
            printf 'Example: todoist-query-api GET /projects\n' >&2
            exit 1
          fi

          METHOD="$1"
          API_PATH="$2"
          shift 2

          case "$API_PATH" in
            /*) ;;
            *)
              printf 'API_PATH must start with /\n' >&2
              exit 1
              ;;
          esac

          TOKEN_FILE="/run/secrets/${hostname}-todoist-api-token"
          if [[ ! -r "$TOKEN_FILE" ]]; then
            printf 'Todoist API token not accessible: %s\n' "$TOKEN_FILE" >&2
            exit 1
          fi

          WORK_DIR=$(${pkgs.coreutils}/bin/mktemp -d -p /var/lib/nx-todoist-api)
          trap '${pkgs.coreutils}/bin/rm -rf "$WORK_DIR"' EXIT
          ${pkgs.coreutils}/bin/chmod 700 "$WORK_DIR"

          TOKEN=$(${pkgs.coreutils}/bin/tr -d '\n' < "$TOKEN_FILE")
          HEADER_FILE="$WORK_DIR/headers"
          printf 'Authorization: Bearer %s\n' "$TOKEN" > "$HEADER_FILE"
          ${pkgs.coreutils}/bin/chmod 600 "$HEADER_FILE"

          ${pkgs.curl}/bin/curl -sSf -X "$METHOD" -H @"$HEADER_FILE" \
            "$@" \
            "https://api.todoist.com/api/v1$API_PATH"
        '';
    in
    {
      init =
        config:
        let
          queueTaskFn =
            {
              topic,
              content,
              emoticon ? null,
              description ? null,
              url ? null,
              projectId ? null,
              sectionId ? null,
              assignee ? null,
              dueString ? null,
              labels ? [ ],
              priority ? null,
              shellVars ? false,
            }:
            let
              script = config.nx.linux.todo.todoist-api.queueScript;
              scriptCmd =
                if !self.isEnabled then
                  null
                else if script != null then
                  "${script}/bin/todoist-queue-task"
                else
                  "todoist-queue-task";
              effectiveProjectId =
                if projectId != null then projectId else config.nx.linux.todo.todoist-api.defaultProjectId;
              effectiveSectionId =
                if sectionId != null then sectionId else config.nx.linux.todo.todoist-api.defaultSectionId;
              asciiChars = lib.stringToCharacters "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~";
              emoticonLooksValid =
                let
                  byteLen = builtins.stringLength emoticon;
                in
                byteLen > 0 && byteLen <= 16 && !(builtins.elem (builtins.substring 0 1 emoticon) asciiChars);
              finalContent =
                if emoticon == null then
                  content
                else if !emoticonLooksValid then
                  throw "linux.todo.todoist-api: emoticon '${emoticon}' does not look like a real emoticon (must be a short non-ASCII symbol)!"
                else
                  "${emoticon} ${content}";
              finalDescription =
                if url != null then
                  (if description != null then "${description}\n\n${url}" else url)
                else
                  description;
              priorityMap = {
                p1 = 4;
                p2 = 3;
                p3 = 2;
                p4 = 1;
              };
              priorityInt =
                if priority == null then
                  null
                else if priorityMap ? ${priority} then
                  priorityMap.${priority}
                else
                  throw "linux.todo.todoist-api: invalid priority '${priority}', must be one of p1, p2, p3, p4!";
              effectiveAssignee =
                if assignee != null then assignee else config.nx.linux.todo.todoist-api.defaultAssignee;
              assigneeId =
                if effectiveAssignee == null then
                  null
                else if config.nx.linux.todo.todoist-api.knownAssignees ? ${effectiveAssignee} then
                  config.nx.linux.todo.todoist-api.knownAssignees.${effectiveAssignee}
                else
                  throw "linux.todo.todoist-api: assignee '${effectiveAssignee}' is not defined in nx.linux.todo.todoist-api.knownAssignees!";
            in
            if scriptCmd == null then
              ":"
            else if shellVars then
              let
                escapeDoubleQuotes = s: builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s;
                doubleQuote = s: "\"${escapeDoubleQuotes s}\"";
              in
              "${
                lib.concatStringsSep " " (
                  [
                    scriptCmd
                    "--topic"
                    (doubleQuote topic)
                    "--content"
                    (doubleQuote finalContent)
                  ]
                  ++ lib.optionals (finalDescription != null) [
                    "--description"
                    (doubleQuote finalDescription)
                  ]
                  ++ lib.optionals (effectiveProjectId != null) [
                    "--project-id"
                    (doubleQuote effectiveProjectId)
                  ]
                  ++ lib.optionals (effectiveSectionId != null) [
                    "--section-id"
                    (doubleQuote effectiveSectionId)
                  ]
                  ++ lib.optionals (assigneeId != null) [
                    "--assignee-id"
                    (doubleQuote assigneeId)
                  ]
                  ++ lib.optionals (dueString != null) [
                    "--due-string"
                    (doubleQuote dueString)
                  ]
                  ++ lib.concatMap (l: [
                    "--label"
                    (doubleQuote l)
                  ]) labels
                  ++ lib.optionals (priorityInt != null) [
                    "--priority"
                    (toString priorityInt)
                  ]
                )
              } || true"
            else
              let
                cmdList = [
                  scriptCmd
                  "--topic"
                  topic
                  "--content"
                  finalContent
                ]
                ++ lib.optionals (finalDescription != null) [
                  "--description"
                  finalDescription
                ]
                ++ lib.optionals (effectiveProjectId != null) [
                  "--project-id"
                  effectiveProjectId
                ]
                ++ lib.optionals (effectiveSectionId != null) [
                  "--section-id"
                  effectiveSectionId
                ]
                ++ lib.optionals (assigneeId != null) [
                  "--assignee-id"
                  assigneeId
                ]
                ++ lib.optionals (dueString != null) [
                  "--due-string"
                  dueString
                ]
                ++ lib.concatMap (l: [
                  "--label"
                  l
                ]) labels
                ++ lib.optionals (priorityInt != null) [
                  "--priority"
                  (toString priorityInt)
                ];
              in
              "${lib.escapeShellArgs cmdList} || true";
        in
        {
          nx.linux.todo.todoist-api.queueTask = queueTaskFn;
        };

      enabled = config: {
        nx.linux.todo.todoist-api.queueScript = queueTaskScript config;

        nx.linux.notifications.pushover.additionalUsers = [ "todoist-api" ];

        nx.linux.monitoring.journal-watcher.ignorePatterns = [
          {
            tag = "nx-todoist-api-drain";
            string = "WARN: failed to create Todoist task from .*, will retry.*";
          }
        ];
      };

      linux.system =
        {
          config,
          apiEndpoint,
          drainInterval,
          drainRandomDelaySec,
          stuckThresholdSec,
          ...
        }:
        let
          hostname = self.host.hostname;
          stateDir = "/var/lib/nx-todoist-api";
          pushoverEnabled = config.nx.linux.notifications.pushover.enable;
          defaultAssignee = config.nx.linux.todo.todoist-api.defaultAssignee;
        in
        {
          assertions = lib.optionals (defaultAssignee != null) [
            {
              assertion = config.nx.linux.todo.todoist-api.knownAssignees ? ${defaultAssignee};
              message = "linux.todo.todoist-api.defaultAssignee '${defaultAssignee}' must be a key in knownAssignees!";
            }
          ];

          users.groups.todoist-api = { };
          users.users.todoist-api = {
            isSystemUser = true;
            group = "todoist-api";
          };

          sops.secrets."${hostname}-todoist-api-token" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "todoist-api-token";
            mode = "0400";
            owner = "todoist-api";
            group = "todoist-api";
          };

          environment.persistence."${self.persist}" = {
            directories = [ stateDir ];
          };

          systemd.tmpfiles.settings."nx-todoist-api" = (
            {
              "${stateDir}".d = {
                mode = "0750";
                user = "root";
                group = "todoist-api";
              };
              "${stateDir}/queue".d = {
                mode = "2770";
                user = "root";
                group = "todoist-api";
              };
              "${stateDir}/state".d = {
                mode = "0700";
                user = "root";
                group = "root";
              };
            }
            // lib.optionalAttrs (helpers.resolveFromHost self [ "impermanence" ] false) {
              "${self.persist}${stateDir}".d = {
                mode = "0750";
                user = "root";
                group = "todoist-api";
              };
              "${self.persist}${stateDir}/queue".d = {
                mode = "2770";
                user = "root";
                group = "todoist-api";
              };
              "${self.persist}${stateDir}/state".d = {
                mode = "0700";
                user = "root";
                group = "root";
              };
            }
          );

          environment.systemPackages = [
            config.nx.linux.todo.todoist-api.queueScript
            queryApiScript
          ];

          systemd.services."nx-todoist-api-drain" = {
            description = "Drain pending Todoist task creation queue";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = "todoist-api";
              Group = "todoist-api";
              ExecStart = pkgs.writeShellScript "nx-todoist-api-drain" ''
                set -uo pipefail

                STATE_DIR=${lib.escapeShellArg stateDir}
                QUEUE_DIR="$STATE_DIR/queue"
                TOKEN_FILE="/run/secrets/${hostname}-todoist-api-token"
                API_ENDPOINT=${lib.escapeShellArg apiEndpoint}
                STUCK_THRESHOLD=${toString stuckThresholdSec}

                if [[ ! -r "$TOKEN_FILE" ]]; then
                  echo "Error: Todoist API token not accessible" >&2
                  exit 1
                fi

                TEMP_CONFIG=$(${pkgs.coreutils}/bin/mktemp)
                trap '${pkgs.coreutils}/bin/rm -f "$TEMP_CONFIG"' EXIT
                ${pkgs.coreutils}/bin/touch "$TEMP_CONFIG"
                ${pkgs.coreutils}/bin/chmod 600 "$TEMP_CONFIG"

                ${pkgs.coreutils}/bin/cat > "$TEMP_CONFIG" <<EOF
                header = "Authorization: Bearer $(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")"
                EOF

                NOW=$(${pkgs.coreutils}/bin/date +%s)
                FAILED=0

                shopt -s nullglob
                for f in "$QUEUE_DIR"/*.json; do
                  [[ -f "$f" ]] || continue
                  if ${pkgs.curl}/bin/curl -fsS -m 30 --connect-timeout 10 -X POST \
                      --config "$TEMP_CONFIG" \
                      -H "Content-Type: application/json" \
                      --data-binary @"$f" \
                      -o /dev/null \
                      "$API_ENDPOINT"; then
                    ${pkgs.coreutils}/bin/rm -f "$f" "$f.escalated"
                  else
                    FAILED=$((FAILED + 1))
                    MTIME=$(${pkgs.coreutils}/bin/stat -c %Y "$f" 2>/dev/null || echo "$NOW")
                    AGE=$((NOW - MTIME))
                    echo "WARN: failed to create Todoist task from $(${pkgs.coreutils}/bin/basename "$f"), will retry (queued for ''${AGE}s)" >&2
                    if [[ $AGE -ge $STUCK_THRESHOLD ]] && [[ ! -f "$f.escalated" ]]; then
                      ${lib.optionalString pushoverEnabled (
                        config.nx.linux.notifications.pushover.send {
                          title = "Todoist Task Stuck";
                          message = "A queued Todoist task has failed to create for over \${STUCK_THRESHOLD}s: $(${pkgs.coreutils}/bin/basename \"$f\")";
                          shellVars = true;
                          type = "warn";
                        }
                      )}
                      ${pkgs.coreutils}/bin/touch "$f.escalated"
                    fi
                  fi
                done

                exit 0
              '';
            };
          };

          systemd.timers."nx-todoist-api-drain" = {
            description = "Periodic Todoist task queue drain";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnActiveSec = "1m";
              OnUnitInactiveSec = drainInterval;
              RandomizedDelaySec = drainRandomDelaySec;
            };
          };
        };
    };
}
