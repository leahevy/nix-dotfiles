args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "signal-bot";

  group = "services";
  input = "linux";

  description = "Signal bot bridging an authorized set of contacts to Home Assistant's conversation API";

  options = {
    configured = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the daemon and bridge services once signal-cli account data has been provisioned manually.";
    };

    mainGroupName = lib.mkOption {
      type = lib.types.str;
      default = "Home Assistant";
      description = "Name of the mandatory main group the bot lives in and keeps synced.";
    };

    profileGivenName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Signal profile given name pushed to the account whenever the profile settings change.";
    };

    profileAbout = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Signal profile about text pushed to the account whenever the profile settings change.";
    };

    enableAvatar = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Push the Signal profile avatar, only enable this once the avatar file exists in the profile files directory.";
    };

    profileAvatar = lib.mkOption {
      type = lib.types.str;
      default = "signal-profile-picture.jpg";
      description = "Profile file name resolved via self.profile.filesPath and used as the Signal profile avatar when enableAvatar is true.";
    };

    enableGroupAvatar = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Push the main group avatar, only enable this once the avatar file exists in the profile files directory.";
    };

    groupAvatar = lib.mkOption {
      type = lib.types.str;
      default = "signal-group-picture.jpg";
      description = "Profile file name resolved via self.profile.filesPath and used as the main group avatar when enableGroupAvatar is true.";
    };

    haUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Base URL of the Home Assistant instance whose conversation API the bot bridges to.";
    };

    haLanguage = lib.mkOption {
      type = lib.types.str;
      default = "en";
      description = "Language code sent with every Home Assistant conversation API request.";
    };

    haAgentId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Suffix of the Home Assistant conversation agent entity id to use (conversation.<suffix>), or null for the default agent.";
    };

    haTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Seconds to wait for a Home Assistant conversation reply before giving up, raise this for slow local models.";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 8720;
      description = "Local port the outbound HTTP send API listens on, bound to 127.0.0.1.";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "signal";
      description = "Subdomain under baseDomain the outbound send API is exposed on when linux.server.nginx is enabled.";
    };

    internalOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restrict the send API vhost to internal clients via the nx_is_internal nginx guard.";
    };

    queueMaxDepth = lib.mkOption {
      type = lib.types.ints.positive;
      default = 20;
      description = "Maximum number of pending outbound messages queued before further sends are rejected.";
    };

    maxSendsPerHour = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      description = "Maximum number of outbound messages sent per rolling hour.";
    };

    maxRequestsPerSenderPerDay = lib.mkOption {
      type = lib.types.ints.positive;
      default = 250;
      description = "Maximum number of Home Assistant conversation requests a single sender can trigger per rolling day.";
    };

    maxSendsPerMinute = lib.mkOption {
      type = lib.types.ints.positive;
      default = 15;
      description = "Maximum number of outbound messages sent per rolling minute, this burst cap applies on top of maxSendsPerHour.";
    };

    inboundMaxAgeMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Maximum age in minutes of an inbound message that is still answered after a restart.";
    };

    maxSplitMessages = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Maximum number of Signal messages a long outbound message is split into before the last part is truncated.";
    };

    boldTitle = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Send the title of an outbound message as bold text using Signal text styles.";
    };

    quoteReplies = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Quote the triggering message when replying in the group chat.";
    };

    conversationFollowUpSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Seconds after a Home Assistant reply in which a further message from the same sender continues that conversation.";
    };

    messages = lib.mkOption {
      type = lib.types.submodule {
        options = {
          haUnreachable = lib.mkOption {
            type = lib.types.str;
            default = "Sorry, I could not reach Home Assistant right now.";
            description = "Reply sent when the Home Assistant conversation request fails.";
          };

          haUnexpectedResponse = lib.mkOption {
            type = lib.types.str;
            default = "Sorry, I did not understand the response from Home Assistant.";
            description = "Reply sent when Home Assistant answers with an unexpected payload.";
          };

          statusTemplate = lib.mkOption {
            type = lib.types.str;
            default = "signal-cli account data: {account}\nHome Assistant: {homeAssistant}";
            description = "Body of the status reply, with the placeholders {account} and {homeAssistant} substituted.";
          };

          statusAccountOk = lib.mkOption {
            type = lib.types.str;
            default = "ok";
            description = "Status wording used when the signal-cli account data is complete.";
          };

          statusAccountMissing = lib.mkOption {
            type = lib.types.str;
            default = "MISSING";
            description = "Status wording used when signal-cli account data is missing.";
          };

          statusHaReachable = lib.mkOption {
            type = lib.types.str;
            default = "reachable";
            description = "Status wording used when Home Assistant answers.";
          };

          statusHaUnreachable = lib.mkOption {
            type = lib.types.str;
            default = "UNREACHABLE";
            description = "Status wording used when Home Assistant does not answer.";
          };

          helpEntryTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{command} - {description}";
            description = "Format of a single help line, with the placeholders {command} and {description} substituted.";
          };

          helpStatusDescription = lib.mkOption {
            type = lib.types.str;
            default = "Show whether signal-cli account data is present and Home Assistant is reachable.";
            description = "Help text describing the status command.";
          };

          helpHelpDescription = lib.mkOption {
            type = lib.types.str;
            default = "List all available commands.";
            description = "Help text describing the help command.";
          };

          helpShortcutTemplate = lib.mkOption {
            type = lib.types.str;
            default = "{command} or {shortcut}";
            description = "Format of the command part of a help line for a command that has a shortcut, with the placeholders {command} and {shortcut} substituted.";
          };

          quoteContextTemplate = lib.mkOption {
            type = lib.types.str;
            default = "[Context - {author} wrote: {message}]\n{text}";
            description = "Prompt sent to Home Assistant when a reply refers to a message outside the current conversation, with the placeholders {author}, {message} and {text} substituted.";
          };

          quoteContextBot = lib.mkOption {
            type = lib.types.str;
            default = "the bot";
            description = "Wording used for {author} when the referenced message came from the bot itself.";
          };

          quoteContextUser = lib.mkOption {
            type = lib.types.str;
            default = "a user";
            description = "Wording used for {author} when the referenced message came from an unknown sender.";
          };

          budgetExhausted = lib.mkOption {
            type = lib.types.str;
            default = "You have reached your daily request limit. Please try again later.";
            description = "Reply sent once when a sender exhausts the daily request budget.";
          };

          scriptCompleted = lib.mkOption {
            type = lib.types.str;
            default = "Done: {command}";
            description = "Reply sent when a script command finished and returned no response of its own, with the placeholders {command} and {argument} substituted.";
          };

          scriptFailed = lib.mkOption {
            type = lib.types.str;
            default = "The command {command} could not be run. Please check Home Assistant.";
            description = "Reply sent when a script command could not be run, with the placeholders {command} and {argument} substituted.";
          };

          scriptArgumentRequired = lib.mkOption {
            type = lib.types.str;
            default = "The command {command} needs a value after the command name.";
            description = "Reply sent when a script command that requires a value was sent without one, with the placeholder {command} substituted.";
          };

          scriptArgumentNotAllowed = lib.mkOption {
            type = lib.types.str;
            default = "The command {command} does not take a value.";
            description = "Reply sent when a value was sent to a script command that takes none, with the placeholder {command} substituted.";
          };

          scriptArgumentTooLong = lib.mkOption {
            type = lib.types.str;
            default = "The value for {command} is too long.";
            description = "Reply sent when the value of a script command exceeds its length limit, with the placeholder {command} substituted.";
          };

          scriptShortcutInvalid = lib.mkOption {
            type = lib.types.str;
            default = "The shortcut {shortcut} must be followed directly by a letter or a digit. Use {command} instead.";
            description = "Reply sent when a message starts with a command shortcut that is not followed by a letter or a digit, with the placeholders {command} and {shortcut} substituted.";
          };

          scriptArgumentInvalid = lib.mkOption {
            type = lib.types.str;
            default = "The value for {command} contains characters that are not allowed.";
            description = "Reply sent when the value of a script command contains control characters, with the placeholder {command} substituted.";
          };
        };
      };
      default = { };
      description = "Texts the bot sends into Signal on its own behalf.";
    };

    scriptCommands = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            script = lib.mkOption {
              type = lib.types.str;
              description = "Object id of the Home Assistant script to run, without the script domain prefix.";
            };

            description = lib.mkOption {
              type = lib.types.str;
              default = "Run a Home Assistant script.";
              description = "Help text describing the command.";
            };

            argument = lib.mkOption {
              type = lib.types.enum [
                "none"
                "optional"
                "required"
              ];
              default = "none";
              description = "Whether the command accepts a value after the command name.";
            };

            argumentVariable = lib.mkOption {
              type = lib.types.str;
              default = "argument";
              description = "Name of the script variable the value is passed as.";
            };

            maxArgumentLength = lib.mkOption {
              type = lib.types.ints.positive;
              default = 200;
              description = "Maximum accepted length of the value in characters.";
            };

            completedMessage = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Reply sent when this command finished and returned no response of its own, overriding the global scriptCompleted message.";
            };

            failedMessage = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Reply sent when this command could not be run, overriding the global scriptFailed message.";
            };

            shortcut = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional single special character that runs this command when a message starts with it followed directly by a letter or a digit, with the rest of the message used as the value.";
            };

          };
        }
      );
      default = { };
      description = "Slash commands that run Home Assistant scripts, keyed by the command name without its leading slash.";
    };

    syncIntervalMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Interval in minutes between main group membership reconciliation runs.";
    };

    additionalUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional usernames that also get their own copy of the send API token.";
    };

    script = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The signal-bot-send script derivation, set in both contexts while the module is enabled";
    };

    sendList = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo (lib.types.listOf lib.types.str));
      default = null;
      description = "Function to generate a signal-bot-send command as a list of arguments";
    };

    send = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.str);
      default = null;
      description = "Function to generate a signal-bot-send shell command string";
    };
  };

  module =
    let
      stateDir = "/var/lib/nx-signal-bot";
      signalCliDataDir = "${stateDir}/signal-cli";
      socketPath = "${stateDir}/daemon.sock";
      stateSubDir = "${stateDir}/state";
      bootstrapLockFile = "${stateDir}/bootstrap.lock";

      phoneNumberSecretName = "signal-bot-phone-number";
      haTokenSecretName = "signal-bot-ha-token";
      apiTokenSecretName = "signal-bot-api-token";
      contactsSecretName = "signal-bot-contacts";

      apiTokenPath = "/run/secrets/${apiTokenSecretName}";
      userApiTokenPathPrefix = "/run/${apiTokenSecretName}-";

      signalBotSendScript =
        config:
        let
          moduleConfig = config.nx.linux.services.signal-bot;
          apiPort = moduleConfig.apiPort;
          configured = moduleConfig.configured;
        in
        pkgs.writeShellScriptBin "signal-bot-send" ''
          set -euo pipefail

          ${lib.optionalString (!configured) ''
            echo "Error: the signal-bot module is not configured on this host!" >&2
            exit 1
          ''}
          if [[ $EUID -eq 0 ]]; then
              TOKEN_FILE="${apiTokenPath}"
          else
              TOKEN_FILE="${userApiTokenPathPrefix}$(${pkgs.coreutils}/bin/id -un)"
          fi

          show_usage() {
              echo "Usage: $0 --message <message> [--title <title>] [--url <url>] [--recipient <contact-name>]" >&2
              echo "       $0 --message-file <path> [--title <title>] [--url <url>] [--recipient <contact-name>]" >&2
              echo "       $0 --stdin  (reads the complete JSON payload from stdin)" >&2
          }

          require_value() {
              if [[ $2 -lt 2 ]]; then
                  echo "Error: $1 requires a value!" >&2
                  show_usage
                  exit 1
              fi
          }

          MESSAGE=""
          MESSAGE_FILE=""
          TITLE=""
          URL=""
          RECIPIENT=""
          HAVE_MESSAGE=0
          READ_STDIN=0

          while [[ $# -gt 0 ]]; do
              case $1 in
                  -h|--help)
                      show_usage
                      exit 0
                      ;;
                  --stdin)
                      READ_STDIN=1
                      shift
                      ;;
                  --message)
                      require_value "$1" $#
                      MESSAGE="$2"
                      HAVE_MESSAGE=1
                      shift 2
                      ;;
                  --message-file)
                      require_value "$1" $#
                      MESSAGE_FILE="$2"
                      HAVE_MESSAGE=1
                      shift 2
                      ;;
                  --title)
                      require_value "$1" $#
                      TITLE="$2"
                      shift 2
                      ;;
                  --url)
                      require_value "$1" $#
                      URL="$2"
                      shift 2
                      ;;
                  --recipient)
                      require_value "$1" $#
                      RECIPIENT="$2"
                      shift 2
                      ;;
                  *)
                      echo "Unknown option: $1" >&2
                      show_usage
                      exit 1
                      ;;
              esac
          done

          if [[ -n "$MESSAGE" && -n "$MESSAGE_FILE" ]]; then
              echo "Error: --message and --message-file are mutually exclusive!" >&2
              show_usage
              exit 1
          fi

          if [[ ! -r "$TOKEN_FILE" ]]; then
              echo "Error: cannot read the signal-bot API token at $TOKEN_FILE!" >&2
              exit 1
          fi

          TOKEN=$(<"$TOKEN_FILE")
          if [[ ! "$TOKEN" =~ ^[A-Za-z0-9._~+/=-]+$ ]]; then
              echo "Error: the signal-bot API token is empty or contains unsupported characters!" >&2
              exit 1
          fi

          WORKDIR=$(${pkgs.coreutils}/bin/mktemp -d)
          trap '${pkgs.coreutils}/bin/rm -rf "$WORKDIR"' EXIT

          if [[ $READ_STDIN -eq 1 ]]; then
              if [[ $HAVE_MESSAGE -eq 1 || -n "$MESSAGE_FILE" || -n "$TITLE" || -n "$URL" || -n "$RECIPIENT" ]]; then
                  echo "Error: --stdin cannot be combined with the other options!" >&2
                  show_usage
                  exit 1
              fi

              ${pkgs.coreutils}/bin/cat >"$WORKDIR/payload.json"

              if ! ${pkgs.jq}/bin/jq -e \
                  'type == "object" and (.message | type) == "string" and (.message | length) > 0' \
                  "$WORKDIR/payload.json" >/dev/null; then
                  echo "Error: --stdin payload must be a JSON object with a non empty message!" >&2
                  exit 1
              fi
          else
              if [[ $HAVE_MESSAGE -eq 0 ]]; then
                  echo "Error: --message or --message-file is required!" >&2
                  show_usage
                  exit 1
              fi

              if [[ -n "$MESSAGE_FILE" ]]; then
                  if [[ ! -r "$MESSAGE_FILE" ]]; then
                      echo "Error: cannot read the message file $MESSAGE_FILE!" >&2
                      exit 1
                  fi
                  ${pkgs.coreutils}/bin/cat "$MESSAGE_FILE" >"$WORKDIR/message"
              else
                  printf '%s' "$MESSAGE" >"$WORKDIR/message"
              fi

              if [[ ! -s "$WORKDIR/message" ]]; then
                  echo "Error: the message must not be empty!" >&2
                  exit 1
              fi

              printf '%s' "$TITLE" >"$WORKDIR/title"
              printf '%s' "$URL" >"$WORKDIR/url"
              printf '%s' "$RECIPIENT" >"$WORKDIR/recipient"

              ${pkgs.jq}/bin/jq -n \
                  --rawfile message "$WORKDIR/message" \
                  --rawfile title "$WORKDIR/title" \
                  --rawfile url "$WORKDIR/url" \
                  --rawfile recipient "$WORKDIR/recipient" \
                  '{message: $message}
                   + (if $title != "" then {title: $title} else {} end)
                   + (if $url != "" then {url: $url} else {} end)
                   + (if $recipient != "" then {recipient: $recipient} else {} end)' \
                  >"$WORKDIR/payload.json"
          fi

          printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" \
              | ${pkgs.curl}/bin/curl -K - -fsS -m 10 -X POST \
                  -H "Content-Type: application/json" \
                  --data-binary @"$WORKDIR/payload.json" \
                  "http://127.0.0.1:${toString apiPort}/v1/send" >/dev/null
        '';
    in
    {
      linux.init =
        config:
        let
          sendListFn =
            {
              message ? null,
              messageFile ? null,
              title ? null,
              url ? null,
              recipient ? null,
              path ? null,
            }:
            let
              script = config.nx.linux.services.signal-bot.script;
              scriptCmd =
                if !self.isEnabled then
                  null
                else if path != null then
                  path
                else if script != null then
                  "${script}/bin/signal-bot-send"
                else
                  "signal-bot-send";
              messageArgs =
                if messageFile != null then
                  [
                    "--message-file"
                    messageFile
                  ]
                else if message != null then
                  [
                    "--message"
                    message
                  ]
                else
                  throw "signal-bot sendList requires either message or messageFile!";
            in
            if scriptCmd == null then
              [ ]
            else
              [ scriptCmd ]
              ++ messageArgs
              ++ lib.optionals (title != null) [
                "--title"
                title
              ]
              ++ lib.optionals (url != null) [
                "--url"
                url
              ]
              ++ lib.optionals (recipient != null) [
                "--recipient"
                recipient
              ];
        in
        {
          nx.linux.services.signal-bot.sendList = sendListFn;

          nx.linux.services.signal-bot.send =
            args:
            let
              cmdList = sendListFn args;
              message =
                if args.messageFile or null != null then
                  throw "signal-bot send does not support messageFile, use sendList instead!"
                else if args.message or null == null then
                  throw "signal-bot send requires message!"
                else
                  args.message;
              payload = builtins.toJSON (
                {
                  inherit message;
                }
                // lib.optionalAttrs (args.title or null != null) { inherit (args) title; }
                // lib.optionalAttrs (args.url or null != null) { inherit (args) url; }
                // lib.optionalAttrs (args.recipient or null != null) { inherit (args) recipient; }
              );
              stdinCmd = lib.escapeShellArgs [
                (builtins.head cmdList)
                "--stdin"
              ];
            in
            if cmdList == [ ] then ":" else "printf '%s' ${lib.escapeShellArg payload} | ${stdinCmd} || true";
        };

      linux.enabled = config: {
        nx.linux.services.signal-bot.script = signalBotSendScript config;
        nx.packages.extra = [ pkgs.signal-cli ];
      };

      linux.system =
        {
          config,
          configured,
          mainGroupName,
          profileGivenName,
          profileAbout,
          enableAvatar,
          profileAvatar,
          enableGroupAvatar,
          groupAvatar,
          haUrl,
          haLanguage,
          haAgentId,
          haTimeoutSeconds,
          apiPort,
          queueMaxDepth,
          maxSendsPerHour,
          maxSendsPerMinute,
          maxRequestsPerSenderPerDay,
          inboundMaxAgeMinutes,
          maxSplitMessages,
          boldTitle,
          quoteReplies,
          conversationFollowUpSeconds,
          messages,
          scriptCommands,
          syncIntervalMinutes,
          additionalUsers,
          script,
          ...
        }:
        let
          groupIdFile = "${stateSubDir}/group-id";
          recipientsFile = "${stateSubDir}/recipients.json";
          profileStateFile = "${stateSubDir}/profile.json";
          handledFile = "${stateSubDir}/handled.json";
          sendStateFile = "${stateSubDir}/send-rate.json";
          senderBudgetFile = "${stateSubDir}/sender-budget.json";

          secretPath = name: config.sops.secrets.${name}.path;

          bridgeScript = self.file "bridge.py";
          pythonEnv = pkgs.python3.withPackages (ps: [
            ps.flask
            ps.pyyaml
            ps.waitress
          ]);

          effectiveProfileGivenName =
            if profileGivenName != null then profileGivenName else self.host.hostname;

          botConfigJson = pkgs.writeText "signal-bot-config.json" (
            builtins.toJSON {
              socket_path = socketPath;
              account_file = secretPath phoneNumberSecretName;
              signal_cli_data_dir = signalCliDataDir;
              group_id_file = groupIdFile;
              recipients_file = recipientsFile;
              profile_state_file = profileStateFile;
              handled_file = handledFile;
              send_state_file = sendStateFile;
              sender_budget_file = senderBudgetFile;
              main_group_name = mainGroupName;
              profile_given_name = effectiveProfileGivenName;
              profile_about = profileAbout;
              profile_avatar = if enableAvatar then self.profile.filesPath profileAvatar else null;
              group_avatar = if enableGroupAvatar then self.profile.filesPath groupAvatar else null;
              ha_url = haUrl;
              ha_language = haLanguage;
              ha_agent_id = if haAgentId == null then null else "conversation.${haAgentId}";
              ha_timeout_seconds = haTimeoutSeconds;
              ha_token_file = secretPath haTokenSecretName;
              api_token_file = secretPath apiTokenSecretName;
              contacts_file = secretPath contactsSecretName;
              api_port = apiPort;
              queue_max_depth = queueMaxDepth;
              max_sends_per_hour = maxSendsPerHour;
              max_sends_per_minute = maxSendsPerMinute;
              max_requests_per_sender_per_day = maxRequestsPerSenderPerDay;
              inbound_max_age_seconds = inboundMaxAgeMinutes * 60;
              max_split_messages = maxSplitMessages;
              bold_title = boldTitle;
              quote_replies = quoteReplies;
              conversation_follow_up_seconds = conversationFollowUpSeconds;
              messages = {
                ha_unreachable = messages.haUnreachable;
                ha_unexpected_response = messages.haUnexpectedResponse;
                status_template = messages.statusTemplate;
                status_account_ok = messages.statusAccountOk;
                status_account_missing = messages.statusAccountMissing;
                status_ha_reachable = messages.statusHaReachable;
                status_ha_unreachable = messages.statusHaUnreachable;
                help_entry_template = messages.helpEntryTemplate;
                help_status_description = messages.helpStatusDescription;
                help_help_description = messages.helpHelpDescription;
                help_shortcut_template = messages.helpShortcutTemplate;
                quote_context_template = messages.quoteContextTemplate;
                quote_context_bot = messages.quoteContextBot;
                quote_context_user = messages.quoteContextUser;
                budget_exhausted = messages.budgetExhausted;
                script_completed = messages.scriptCompleted;
                script_failed = messages.scriptFailed;
                script_argument_required = messages.scriptArgumentRequired;
                script_argument_not_allowed = messages.scriptArgumentNotAllowed;
                script_argument_too_long = messages.scriptArgumentTooLong;
                script_argument_invalid = messages.scriptArgumentInvalid;
                script_shortcut_invalid = messages.scriptShortcutInvalid;
              };
              script_commands = lib.mapAttrs' (
                name: command:
                lib.nameValuePair "/${name}" {
                  script = command.script;
                  description = command.description;
                  argument = command.argument;
                  argument_variable = command.argumentVariable;
                  max_argument_length = command.maxArgumentLength;
                  completed_message = command.completedMessage;
                  failed_message = command.failedMessage;
                  shortcut = command.shortcut;
                }
              ) scriptCommands;
            }
          );

          permissionsScript = pkgs.writeShellScript "nx-signal-bot-fix-permissions" ''
            set -euo pipefail

            if [ ! -d "${stateDir}" ]; then
                exit 0
            fi

            ${pkgs.coreutils}/bin/chown -R signal-bot:signal-bot "${stateDir}"
            ${pkgs.coreutils}/bin/chmod 0750 "${stateDir}"
            ${pkgs.findutils}/bin/find "${stateDir}" -mindepth 1 -type d \
                -exec ${pkgs.coreutils}/bin/chmod 0700 {} +
            ${pkgs.findutils}/bin/find "${stateDir}" -mindepth 1 -type f \
                -exec ${pkgs.coreutils}/bin/chmod 0600 {} +
          '';

          hardening = {
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictRealtime = true;
            LockPersonality = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
            ];
            UMask = "0077";
            ReadWritePaths = [ stateDir ];
          };

          haRest =
            if haUrl == null then
              null
            else if lib.hasPrefix "https://" haUrl then
              lib.removePrefix "https://" haUrl
            else if lib.hasPrefix "http://" haUrl then
              lib.removePrefix "http://" haUrl
            else
              null;

          haHostPort = if haRest == null then null else lib.head (lib.splitString "/" haRest);

          haHost =
            if haHostPort == null then
              null
            else if lib.hasPrefix "[" haHostPort then
              lib.head (lib.splitString "]" (lib.removePrefix "[" haHostPort))
            else
              lib.head (lib.splitString ":" haHostPort);

          haLoopbackHosts = [
            "localhost"
            "127.0.0.1"
            "::1"
          ];

          scriptShortcutChars = [
            "!"
            "?"
            "@"
            "#"
            "$"
            "%"
            "&"
            "*"
            "+"
            "="
            "~"
            "^"
            "."
            ","
            ":"
            ";"
            "_"
            "-"
            "|"
            "<"
            ">"
          ];

          scriptShortcuts = lib.filter (shortcut: shortcut != null) (
            lib.mapAttrsToList (_: command: command.shortcut) scriptCommands
          );

          tokenUsers = lib.unique ([ self.host.mainUser.username ] ++ additionalUsers);

          perUserTokenSecrets = lib.listToAttrs (
            map (username: {
              name = "${apiTokenSecretName}-${username}";
              value = {
                format = "binary";
                sopsFile = self.profile.secretsPath apiTokenSecretName;
                mode = "0440";
                owner = "root";
                group = config.users.users.${username}.group;
                path = "${userApiTokenPathPrefix}${username}";
              };
            }) tokenUsers
          );
        in
        {
          users.groups.signal-bot = { };
          users.users.signal-bot = {
            isSystemUser = true;
            group = "signal-bot";
            home = stateDir;
          };

          environment.persistence."${self.persist}" = {
            directories = [ stateDir ];
          };

          systemd.tmpfiles.settings."10-signal-bot" = {
            "${stateDir}".d = {
              mode = "0750";
              user = "signal-bot";
              group = "signal-bot";
            };
          }
          // lib.optionalAttrs self.host.impermanence {
            "${self.persist}${stateDir}".d = {
              mode = "0750";
              user = "signal-bot";
              group = "signal-bot";
            };
          };

          environment.systemPackages = lib.optionals (script != null) [ script ];

          assertions = lib.optionals configured [
            {
              assertion = haUrl != null;
              message = "linux.services.signal-bot requires haUrl to be set when configured is true!";
            }
            {
              assertion = haUrl == null || (haHost != null && haHost != "");
              message = "linux.services.signal-bot requires haUrl to start with http:// or https:// followed by a host!";
            }
            {
              assertion =
                haUrl == null
                || haHost == null
                || lib.hasPrefix "https://" haUrl
                || lib.elem haHost haLoopbackHosts;
              message = "linux.services.signal-bot requires haUrl to use https unless Home Assistant runs on loopback!";
            }
            {
              assertion = lib.all (name: builtins.match "[a-z0-9-]+" name != null) (lib.attrNames scriptCommands);
              message = "linux.services.signal-bot requires every scriptCommands name to consist of lowercase letters, digits or dashes without a leading slash!";
            }
            {
              assertion =
                !lib.any (
                  name:
                  lib.elem name [
                    "help"
                    "status"
                  ]
                ) (lib.attrNames scriptCommands);
              message = "linux.services.signal-bot cannot replace the built-in help and status commands through scriptCommands!";
            }
            {
              assertion = lib.all (command: builtins.match "[a-z0-9_]+" command.script != null) (
                lib.attrValues scriptCommands
              );
              message = "linux.services.signal-bot requires every scriptCommands script to be a Home Assistant object id of lowercase letters, digits or underscores!";
            }
            {
              assertion = lib.all (shortcut: lib.elem shortcut scriptShortcutChars) scriptShortcuts;
              message = "linux.services.signal-bot requires every scriptCommands shortcut to be one of ${lib.concatStrings scriptShortcutChars}!";
            }
            {
              assertion = lib.length scriptShortcuts == lib.length (lib.unique scriptShortcuts);
              message = "linux.services.signal-bot requires every scriptCommands shortcut to be used by only one command!";
            }
          ];

          sops.secrets = lib.mkIf configured (
            {
              "${phoneNumberSecretName}" = {
                format = "binary";
                sopsFile = self.profile.secretsPath phoneNumberSecretName;
                mode = "0440";
                owner = "signal-bot";
                group = "signal-bot";
                restartUnits = [ "nx-signal-bot.service" ];
              };
              "${haTokenSecretName}" = {
                format = "binary";
                sopsFile = self.profile.secretsPath haTokenSecretName;
                mode = "0440";
                owner = "signal-bot";
                group = "signal-bot";
                restartUnits = [ "nx-signal-bot.service" ];
              };
              "${apiTokenSecretName}" = {
                format = "binary";
                sopsFile = self.profile.secretsPath apiTokenSecretName;
                path = apiTokenPath;
                mode = "0400";
                owner = "signal-bot";
                group = "signal-bot";
                restartUnits = [ "nx-signal-bot.service" ];
              };
              "${contactsSecretName}" = {
                format = "yaml";
                key = "";
                sopsFile = self.profile.secretsPath "${contactsSecretName}.yaml";
                mode = "0440";
                owner = "signal-bot";
                group = "signal-bot";
                restartUnits = [ "nx-signal-bot.service" ];
              };
            }
            // perUserTokenSecrets
          );

          systemd.services.nx-signal-bot-permissions = lib.mkIf configured {
            description = "NX Signal Bot Data Permission Fixup";
            wantedBy = [ "multi-user.target" ];
            before = [ "nx-signal-cli-daemon.service" ];
            requiredBy = [ "nx-signal-cli-daemon.service" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${permissionsScript}";
            };
          };

          systemd.services.nx-signal-cli-daemon = lib.mkIf configured {
            description = "NX Signal CLI JSON-RPC Daemon";
            wantedBy = [ "multi-user.target" ];

            unitConfig = {
              StartLimitIntervalSec = "1h";
              StartLimitBurst = 10;
            };

            serviceConfig = hardening // {
              Type = "simple";
              User = "signal-bot";
              Group = "signal-bot";
              Restart = "always";
              RestartSec = "30";
              ExecStartPre = "${pkgs.coreutils}/bin/test -f ${signalCliDataDir}/data/accounts.json";
              ExecStart = "${pkgs.signal-cli}/bin/signal-cli --scrub-log --config ${signalCliDataDir} daemon --socket ${socketPath} --receive-mode manual --ignore-attachments --ignore-avatars --ignore-stickers --ignore-stories";
            };
          };

          systemd.services.nx-signal-bot = lib.mkIf configured {
            description = "NX Signal Bot Bridge";
            wantedBy = [ "multi-user.target" ];
            after = [ "nx-signal-cli-daemon.service" ];
            requires = [ "nx-signal-cli-daemon.service" ];

            unitConfig = {
              StartLimitIntervalSec = "1h";
              StartLimitBurst = 10;
            };

            serviceConfig = hardening // {
              Type = "simple";
              User = "signal-bot";
              Group = "signal-bot";
              Restart = "always";
              RestartSec = "30";
              TimeoutStartSec = "900";
              ExecStartPre = "${pkgs.util-linux}/bin/flock ${bootstrapLockFile} ${pythonEnv}/bin/python3 ${bridgeScript} bootstrap ${botConfigJson}";
              ExecStart = "${pythonEnv}/bin/python3 ${bridgeScript} serve ${botConfigJson}";
            };
          };

          systemd.services.nx-signal-bot-sync = lib.mkIf configured {
            description = "NX Signal Bot Main Group Reconciliation";
            after = [ "nx-signal-bot.service" ];
            requisite = [ "nx-signal-bot.service" ];

            serviceConfig = hardening // {
              Type = "oneshot";
              User = "signal-bot";
              Group = "signal-bot";
              TimeoutStartSec = "900";
              ExecStart = "${pkgs.util-linux}/bin/flock -n -E 0 ${bootstrapLockFile} ${pythonEnv}/bin/python3 ${bridgeScript} bootstrap ${botConfigJson}";
            };
          };

          systemd.timers.nx-signal-bot-sync = lib.mkIf configured {
            description = "NX Signal Bot Main Group Reconciliation Timer";
            wantedBy = [ "timers.target" ];

            timerConfig = {
              OnActiveSec = "${toString syncIntervalMinutes}min";
              OnUnitActiveSec = "${toString syncIntervalMinutes}min";
              AccuracySec = "1min";
              Unit = "nx-signal-bot-sync.service";
            };
          };
        };

      ifEnabled.linux.server.nginx = {
        system =
          {
            config,
            apiPort,
            subdomain,
            configured,
            internalOnly,
            ...
          }:
          let
            domain = self.host.remote.baseDomain;
            internalGuard = lib.optionalString internalOnly ''
              if ($nx_is_internal = 0) { return 403; }
            '';
            proxyHeaders = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          in
          lib.mkIf (configured && domain != null) {
            services.nginx.virtualHosts."${subdomain}.${domain}" = {
              useACMEHost = domain;
              forceSSL = true;
              locations."/v1/send" = {
                proxyPass = "http://127.0.0.1:${toString apiPort}/v1/send";
                recommendedProxySettings = false;
                extraConfig = internalGuard + proxyHeaders;
              };
              locations."/".return = "404";
            };
          };
      };

      ifEnabled.linux.server.healthchecks = {
        enabled =
          config:
          let
            rpcPingScript = pkgs.writers.writePython3Bin "signal-bot-rpc-ping" { } ''
              import json
              import socket
              import sys
              import time

              SOCKET_PATH = "${socketPath}"
              REQUEST_ID = "nx-healthcheck"
              DEADLINE = time.monotonic() + 10

              try:
                  sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                  sock.settimeout(5)
                  sock.connect(SOCKET_PATH)
                  request = {
                      "jsonrpc": "2.0",
                      "method": "version",
                      "id": REQUEST_ID,
                  }
                  sock.sendall(json.dumps(request).encode() + b"\n")
                  stream = sock.makefile("rb")
                  while time.monotonic() < DEADLINE:
                      line = stream.readline()
                      if not line:
                          break
                      try:
                          message = json.loads(line)
                      except json.JSONDecodeError:
                          continue
                      if message.get("id") == REQUEST_ID:
                          if "result" in message:
                              sys.exit(0)
                          print("version request returned an error")
                          sys.exit(1)
              except OSError as e:
                  print(f"cannot reach the daemon socket: {e}")
                  sys.exit(1)
              print("no version response within 10s")
              sys.exit(1)
            '';
          in
          lib.mkIf config.nx.linux.services.signal-bot.configured {
            nx.linux.server.healthchecks.requireServicesUp = [
              "nx-signal-cli-daemon.service"
              "nx-signal-bot.service"
            ];
            nx.linux.server.healthchecks.regularHealthChecks."R+55 - Signal bot RPC" = ''
              if ! _signal_rpc=$(${rpcPingScript}/bin/signal-bot-rpc-ping 2>&1); then
                printf 'signal-cli RPC: %s\n' "$_signal_rpc" >&3
                exit 1
              fi
            '';
          };
      };
    };
}
