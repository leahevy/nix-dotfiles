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
  modelVersionsByAlias = {
    opus = [
      "5"
      "4.8"
      "4.7"
      "4.6"
      "4.5"
    ];
    sonnet = [
      "5"
      "4.6"
      "4.5"
    ];
    haiku = [ "4.5" ];
    fable = [ "5" ];
  };

  modelAliasEnvVars = {
    opus = "ANTHROPIC_DEFAULT_OPUS_MODEL";
    sonnet = "ANTHROPIC_DEFAULT_SONNET_MODEL";
    haiku = "ANTHROPIC_DEFAULT_HAIKU_MODEL";
    fable = "ANTHROPIC_DEFAULT_FABLE_MODEL";
  };

  modelIdFor = alias: version: "claude-${alias}-${lib.replaceStrings [ "." ] [ "-" ] version}";

  modelVersionPins = {
    opus = "4.8";
    sonnet = "4.6";
    haiku = "4.5";
    fable = "5";
  };

  hookEvents = [
    "SessionStart"
    "Setup"
    "UserPromptSubmit"
    "UserPromptExpansion"
    "PreToolUse"
    "PermissionRequest"
    "PermissionDenied"
    "PostToolUse"
    "PostToolUseFailure"
    "PostToolBatch"
    "Notification"
    "MessageDisplay"
    "SubagentStart"
    "SubagentStop"
    "TaskCreated"
    "TaskCompleted"
    "Stop"
    "StopFailure"
    "TeammateIdle"
    "InstructionsLoaded"
    "ConfigChange"
    "CwdChanged"
    "DirectoryAdded"
    "FileChanged"
    "WorktreeCreate"
    "WorktreeRemove"
    "PreCompact"
    "PostCompact"
    "Elicitation"
    "ElicitationResult"
    "SessionEnd"
  ];

  soundHookEvents = [
    "Stop"
    "StopFailure"
    "Notification"
    "PermissionRequest"
    "PermissionDenied"
    "PostToolUseFailure"
    "TaskCompleted"
    "PreCompact"
    "PostCompact"
    "Elicitation"
  ];

  soundHookEventsDisabledByDefault = [
    "Stop"
  ];

  suppressedNotifications = [
    "Claude is waiting for your input"
  ];

  hookHandlerType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this hook handler is active.";
      };
      matcher = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Tool-name matcher for the handler, null matches every event.";
      };
      command = lib.mkOption {
        type = lib.types.oneOf [
          lib.types.package
          lib.types.path
          lib.types.str
        ];
        description = "Executable run when the hook fires.";
      };
    };
  };
in
{
  name = "claude";

  group = "dev";
  input = "common";

  unfree = [ "claude-code" ];

  options = {
    style = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf helpers.optionsHelpers.recursiveStringListType);
      default = { };
      description = "Claude-specific personality and response style rules.";
    };

    instructions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf helpers.optionsHelpers.recursiveStringListType);
      default = { };
      description = "Claude-specific instructions.";
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.either lib.types.str (
          lib.types.submodule {
            options = {
              description = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Skill description.";
              };
              text = lib.mkOption {
                type = lib.types.str;
                description = "Skill instructions.";
              };
            };
          }
        )
      );
      default = { };
      description = "Claude-specific skills.";
    };

    agents = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            description = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Agent description.";
            };
            text = lib.mkOption {
              type = lib.types.str;
              description = "Agent instructions.";
            };
            tools = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "Read"
                "Edit"
                "Write"
              ];
              description = "Allowed tools.";
            };
          };
        }
      );
      default = { };
      description = "Claude-specific custom agents.";
    };

    autoCompact = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically compact the conversation as it approaches the context limit.";
    };

    autoCompactWindow = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 350000;
      description = "Context capacity in tokens used for auto-compaction calculations.";
    };

    autoCompactPercent = lib.mkOption {
      type = lib.types.nullOr (lib.types.ints.between 1 100);
      default = 85;
      description = "Percentage of the auto-compaction window at which compaction triggers.";
    };

    contextWarnPercent = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 80;
      description = "Percentage of the auto-compaction trigger at which the statusline context segment turns red.";
    };

    model = lib.mkOption {
      type = lib.types.enum [
        "haiku"
        "opus"
        "sonnet"
        "fable"
      ];
      default = "opus";
      description = "Default Claude Code model.";
    };

    modelVersions = lib.mkOption {
      type = lib.types.submodule {
        options = lib.mapAttrs (
          alias: versions:
          lib.mkOption {
            type = lib.types.nullOr (lib.types.enum versions);
            default = modelVersionPins.${alias};
            description = "Version the ${alias} alias resolves to, null selects the newest known version.";
          }
        ) modelVersionsByAlias;
      };
      default = { };
      description = "Pins every Claude Code model alias to a specific model version.";
    };

    effortLevel = lib.mkOption {
      type = lib.types.enum [
        "low"
        "medium"
        "high"
        "xhigh"
      ];
      default = "medium";
      description = "Default Claude Code effort level.";
    };

    notifyEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable agent push notifications.";
    };

    voiceModeEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable voice mode.";
    };

    defaultVoiceMode = lib.mkOption {
      type = lib.types.enum [
        "tap"
        "hold"
      ];
      default = "tap";
      description = "Default mode for voice mode.";
    };

    alwaysThinkingEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable extended thinking by default.";
    };

    fileCheckpointingEnabled = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable file-state checkpoints for /rewind.";
    };

    disableWorkflows = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable dynamic workflows.";
    };

    enableArtifact = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Artifact tool.";
    };

    editorMode = lib.mkOption {
      type = lib.types.str;
      default = "normal";
      description = "Input editor mode.";
    };

    askUserQuestionTimeout = lib.mkOption {
      type = lib.types.str;
      default = "never";
      description = "Auto-continue timeout for AskUserQuestion prompts.";
    };

    spinnerTipsEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show tips in the spinner.";
    };

    awaySummaryEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show a recap when returning to a session.";
    };

    autoScrollEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically scroll to the latest output.";
    };

    remoteControlAtStartup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Remote Control for all sessions at startup.";
    };

    permissionMode = lib.mkOption {
      type = lib.types.enum [
        "manual"
        "acceptEdits"
        "plan"
        "dontAsk"
        "auto"
        "bypassPermissions"
      ];
      default = "manual";
      description = "Default permission mode Claude Code starts sessions in.";
    };

    useAutoModeDuringPlan = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Let plan mode use auto mode semantics to auto-approve read-only commands while planning.";
    };

    delegateToSubagents = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Delegate implementation, review, search, and web search work to subagents.";
    };

    subagentModel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "haiku"
          "sonnet"
          "opus"
          "fable"
        ]
      );
      default = null;
      description = "Model for spawned subagents, null uses the main session model with no override.";
    };

    maxConcurrentSubagents = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Maximum number of subagents to run concurrently when delegation is enabled.";
    };

    allowForkSubagents = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow Claude to spawn fork subagents.";
    };

    allowNestedSubagents = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow subagents to spawn further subagents.";
    };

    defaultSubagentType = lib.mkOption {
      type = lib.types.str;
      default = "general-purpose";
      description = "Default agent type Claude spawns for general subagent work.";
    };

    hookHandlers = lib.mkOption {
      type = lib.types.submodule {
        options = lib.genAttrs hookEvents (
          event:
          lib.mkOption {
            type = lib.types.nullOr hookHandlerType;
            default = null;
            description = "Handler for the ${event} lifecycle hook, null installs no handler.";
          }
        );
      };
      default = { };
      description = "Claude Code lifecycle hook handlers, one per supported event.";
    };

    enableDefaultHookHandlers = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the built-in default hook handlers.";
    };

    guardrailDisallowedPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra regexes matched against resolved tool paths that the built-in guardrail denies.";
    };

    guardrailDisallowedDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra directory paths (prefix-matched, tilde-expanded) that the built-in guardrail denies access to.";
    };

    guardrailDisallowedCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra regexes matched against Bash commands that the built-in guardrail denies.";
    };

    allowedWebFetchDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra domain regexes that WebFetch is allowed to access without prompting.";
    };

    sounds = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Play sounds on Claude Code hook events.";
          };
          sink = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "headset"
                "speaker"
              ]
            );
            default = "speaker";
            description = "Audio sink for hook sounds, null uses the system default sink.";
          };
          hooks = lib.mkOption {
            type = lib.types.submodule {
              options = lib.genAttrs soundHookEvents (
                event:
                lib.mkOption {
                  type = lib.types.bool;
                  default = !builtins.elem event soundHookEventsDisabledByDefault;
                  description = "Play a sound on the ${event} hook.";
                }
              );
            };
            default = { };
            description = "Per-hook sound enable flags.";
          };
        };
      };
      default = { };
      description = "Sound notifications for Claude Code lifecycle hooks.";
    };
  };

  submodules = {
    common = {
      dev = [ "agents" ];
    };
  };

  module = {
    linux.enabled = config: {
      nx.common.dev.claude.guardrailDisallowedDirectories = [
        "/boot"
        "/root"
        "/run"
        "/proc"
        "/sys"
      ];
    };

    darwin.enabled = config: {
      nx.common.dev.claude.guardrailDisallowedDirectories = [
        "/System"
        "/Library"
        "/private"
      ];
    };

    enabled =
      config:
      let
        delegateEnabled = config.nx.common.dev.claude.delegateToSubagents;
        agentModel = config.nx.common.dev.claude.subagentModel;
        maxAgents = config.nx.common.dev.claude.maxConcurrentSubagents;
        allowFork = config.nx.common.dev.claude.allowForkSubagents;
        allowNested = config.nx.common.dev.claude.allowNestedSubagents;
        defaultAgentType = config.nx.common.dev.claude.defaultSubagentType;
        resolvedAgentModel = if agentModel != null then agentModel else config.nx.common.dev.claude.model;
        baseInstructions = {
          "90 - Claude" = [
            "Use the conversation as initial context, then read only the files and local context required to complete the request."
            "Batch all changes into as few operations as possible."
            "Don't analyse too much on first feasibility questions to avoid wasting tokens."
            "If a background event (task notification, agent message, command result) triggers a turn but you have already reported everything relevant to the user in a prior response this session, run Bash 'true' as a no-op instead of repeating yourself. Use description: 'Background task completed' on the Bash call. Do not also write text; the no-op is the entire response."
            "If a tool call fails only because its approval could not be delivered (a transient approval-path error asking to try again, never a nonzero exit code or other tool error), silently reissue it up to three times before telling the user, and do not print that message."
            [
              "Use the AskUserQuestion tool when:"
              "The user needs to pick between 2-4 distinct implementation approaches"
              "A decision has clear trade-offs that benefit from side-by-side comparison"
              "You would otherwise ask a free-form question the user would answer with a one-word reply"
              "You did a review and we need to make decisions for fixing individual issues one by one"
              "Even with many choices to present, still use this tool: split them across multiple questions rather than skipping it, since each question accepts at most 4 options and a single call accepts at most 4 questions"
            ]
            [
              "Use the Task tools (TaskCreate, TaskUpdate, TaskGet, TaskList) to track work when:"
              "A task, plan implementation, or review requires more than 1 step"
              "The work is non-trivial multi-step implementation work, not just a mental plan"
              "TaskCreate adds one pending item, TaskUpdate patches one item by taskId, TaskGet and TaskList read the current list"
              "Create tasks before starting, set each to in_progress when you begin it and completed as soon as it's done, don't batch updates; delete a task you no longer need with status deleted"
            ]
            [
              "Remote / Mobile Sessions"
              "When the user says they are remote or mobile (or using a phone or tablet), show every change verbatim in the chat - as an inline diff or as the full updated content - before issuing the actual Edit/Write/Bash tool call. This lets the user review and approve the changes without needing to inspect the tool call details."
            ]
          ]
          ++ lib.optional (!delegateEnabled) "Keep sub-agents to a minimum.";
        }
        // lib.optionalAttrs delegateEnabled {
          "95 - Subagent Workflow" = [
            "All implementation, review, search, and web search work must be executed in subagents, not inline in the main session."
            "Always pass model: ${resolvedAgentModel} to the Agent tool when spawning subagents."
            "Always pass subagent_type: ${defaultAgentType} to the Agent tool unless spawning a named custom agent type."
            "Keep no more than ${builtins.toString maxAgents} subagents running concurrently."
            "When a subagent sends you a message: if it is a progress update, do NOT reply (replying resumes the subagent and causes a redundant extra turn); if it is a blocking question, reply immediately via SendMessage (at minimum 'Continue') so the subagent is not deadlocked. Never leave a waiting subagent without a reply."
          ];
        };
        baseSkills = { };
        baseAgents = { };

        pythonHookLib = ''
          import json
          import sys
          import os
          import re
          import shutil
          import subprocess
          from datetime import datetime

          HOME = os.path.expanduser("~")
          GIT = "${pkgs.git}/bin/git"


          def load(strict=False):
              try:
                  return json.loads(sys.stdin.read() or "{}")
              except Exception:
                  if strict:
                      deny("guardrail could not parse the hook input")
                  return {}


          def emit(obj):
              json.dump(obj, sys.stdout)
              sys.exit(0)


          def deny(reason, event="PreToolUse"):
              emit({"hookSpecificOutput": {"hookEventName": event, "permissionDecision": "deny", "permissionDecisionReason": reason}})


          def ask(reason, event="PreToolUse"):
              emit({"hookSpecificOutput": {"hookEventName": event, "permissionDecision": "ask", "permissionDecisionReason": reason}})


          def allow(reason, event="PreToolUse"):
              emit({"hookSpecificOutput": {"hookEventName": event, "permissionDecision": "allow", "permissionDecisionReason": reason}})


          def context(text, event="SessionStart"):
              sys.stdout.write(text + "\n")
              sys.exit(0)


          def tool_input(data):
              return data.get("tool_input") or {}


          def tool_path(data):
              ti = tool_input(data)
              return ti.get("file_path") or ti.get("path") or ti.get("notebook_path")


          def resolve(cwd, path):
              if not os.path.isabs(path):
                  path = os.path.join(cwd, path)
              return os.path.normpath(path)


          def under(path, base):
              return path == base or path.startswith(base + os.sep)


          def matches(text, patterns):
              return any(re.search(pattern, text) for pattern in patterns)


          def run(cmd, cwd):
              try:
                  result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=5)
                  return result.stdout.strip()
              except Exception:
                  return ""


          def state_dir():
              base = os.environ.get("XDG_RUNTIME_DIR") or os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local", "state")
              path = os.path.join(base, "nx-claude")
              os.makedirs(path, exist_ok=True)
              return path


          def safe_id(session_id):
              return re.sub(r"[^A-Za-z0-9_-]", "_", session_id or "default")


          def pointer_path(session_id):
              return os.path.join(state_dir(), "precompact-last-" + safe_id(session_id))


          def snapshot(src, session_id):
              if not src or not os.path.isfile(src):
                  return None
              directory = state_dir()
              dest = os.path.join(directory, "precompact-" + datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + safe_id(session_id) + ".jsonl")
              shutil.copyfile(src, dest)
              with open(pointer_path(session_id), "w") as handle:
                  handle.write(dest + "\n")
              return dest


          def project_tree(root, max_depth=6, max_dirs=1000):
              root = os.path.abspath(root)
              dirs_out = []
              truncated = False
              for current, dirs, files in os.walk(root):
                  rel = os.path.relpath(current, root)
                  depth = 0 if rel == "." else rel.count(os.sep) + 1
                  dirs[:] = sorted(d for d in dirs if not d.startswith("."))
                  if depth >= max_depth:
                      dirs[:] = []
                  if rel != "." and any(not f.startswith(".") for f in files):
                      if len(dirs_out) >= max_dirs:
                          truncated = True
                          break
                      dirs_out.append(rel + os.sep)
              dirs_out.sort()
              if truncated:
                  dirs_out.append("... (more entries omitted, limit " + str(max_dirs) + " reached)")
              return "\n".join(dirs_out)


          def full_files(root, max_depth=10, max_files=5000):
              root = os.path.abspath(root)
              files_out = []
              for current, dirs, files in os.walk(root):
                  rel = os.path.relpath(current, root)
                  depth = 0 if rel == "." else rel.count(os.sep) + 1
                  dirs[:] = sorted(d for d in dirs if not d.startswith("."))
                  if depth >= max_depth:
                      dirs[:] = []
                  prefix = "" if rel == "." else rel + os.sep
                  for name in sorted(f for f in files if not f.startswith(".")):
                      if len(files_out) >= max_files:
                          return None
                      files_out.append(prefix + name)
              files_out.sort()
              return "\n".join(files_out)


          def shallow_files(root, max_file_depth=1):
              root = os.path.abspath(root)
              files_out = []
              for current, dirs, files in os.walk(root):
                  rel = os.path.relpath(current, root)
                  depth = 0 if rel == "." else rel.count(os.sep) + 1
                  dirs[:] = sorted(d for d in dirs if not d.startswith("."))
                  if depth >= max_file_depth:
                      dirs[:] = []
                  if depth > max_file_depth:
                      continue
                  prefix = "" if rel == "." else rel + os.sep
                  for name in sorted(f for f in files if not f.startswith(".")):
                      files_out.append(prefix + name)
              files_out.sort()
              return "\n".join(files_out)
        '';

        autoDenyReasons = [
          "find with side-effecting action"
          "nix store traversal is blocked"
        ];

        forbiddenCommandWords = [
          "sudo"
          "mkfs"
          "dmesg"
          "pkill"
          "poweroff"
          "reboot"
        ];

        bakedWebDomains = [
          "github.com"
          "docs.github.com"
          "gist.github.com"
          "api.github.com"
          "raw.githubusercontent.com"
          "gitlab.com"
          "nixos.wiki"
          "wiki.nixos.org"
          "mynixos.com"
          "wiki.archlinux.org"
          "hackage.haskell.org"
          "haskell.org"
          "docs.anthropic.com"
          "code.claude.com"
          "platform.claude.com"
          "search.nixos.org"
          "nixos.org"
          "nix.dev"
          "man7.org"
          "systemd.io"
          "freedesktop.org"
          "docs.python.org"
          "doc.rust-lang.org"
          "docs.rs"
          "pkg.go.dev"
          "nix-community.github.io"
          "docs.renovatebot.com"
        ];

        forkDenyBlock = lib.optionalString (!allowFork) ''
          if tool_name == "Agent" and tool_input(data).get("subagent_type") == "fork":
              deny("Fork subagents are disabled; use subagent_type '${defaultAgentType}' instead")
        '';

        nestedDenyBlock = lib.optionalString (!allowNested) ''
          if tool_name == "Agent" and data.get("agent_id"):
              deny("Subagents may not spawn further subagents")
        '';

        guardrailBody = ''
          NXCONFIG = os.path.join(HOME, ".config", "nx", "nxconfig")
          CLAUDE_TMP = os.path.join("/tmp", "claude-" + str(os.getuid()))
          CLAUDE_HOME = os.path.join(HOME, ".claude")
          NX_INPUT_ROOTS = [
              "/etc/nx/inputs",
              os.path.join(HOME, ".local", "share", "nx", "inputs"),
          ]

          def nxconfig_allowed(target):
              base = os.path.basename(target)
              return target.endswith(".md") or base in ("flake.nix", "flake.lock")
          SECRET_DIRS = [
              os.path.join(HOME, ".ssh"),
              os.path.join(HOME, ".gnupg"),
              os.path.join(HOME, ".config", "sops-nix", "secrets"),
              os.path.join(HOME, ".config", "sops"),
          ]
          SECRET_FILE = re.compile(r"(\.pem|\.key|\.age|/id_rsa|/id_ed25519|/id_ecdsa|/\.env(\.|$))")
          EXTRA_PATH_DENY = ${builtins.toJSON config.nx.common.dev.claude.guardrailDisallowedPaths}
          EXTRA_CMD_DENY = ${builtins.toJSON config.nx.common.dev.claude.guardrailDisallowedCommands}
          EXTRA_DIR_DENY = [os.path.normpath(os.path.expanduser(d)) for d in ${builtins.toJSON config.nx.common.dev.claude.guardrailDisallowedDirectories}]
          FORBIDDEN_COMMANDS = ${builtins.toJSON forbiddenCommandWords}

          GREP_FAMILY = ("grep", "egrep", "fgrep")
          READONLY_FILTERS = GREP_FAMILY + (
              "rg", "tree", "sort", "head", "tail", "wc", "cut", "cat",
              "nl", "tac", "rev", "uniq", "comm", "column", "fmt", "fold",
              "ls", "tr", "jq", "yq", "date", "basename", "dirname", "printf", "diff",
          )

          OPERATORS = frozenset(['&&', '||', ';'])

          FIND_ACTION_FLAGS = frozenset([
              '-exec', '-execdir', '-ok', '-okdir', '-delete',
              '-fprintf', '-fprint', '-fprint0', '-fls',
          ])

          def _tokenize(cmd):
              import shlex
              try:
                  lex = shlex.shlex(cmd, posix=True)
                  lex.whitespace_split = False
                  lex.whitespace = ' \t'
                  lex.wordchars += '-./=~%@+:,'
                  lex.commenters = ""
                  raw = list(lex)
              except ValueError:
                  return None
              merged, i = [], 0
              while i < len(raw):
                  if raw[i] in ('&', '|') and i + 1 < len(raw) and raw[i + 1] == raw[i]:
                      merged.append(raw[i] * 2)
                      i += 2
                  else:
                      merged.append(raw[i])
                      i += 1
              return merged

          def _split_on(tokens, ops):
              parts, cur = [], []
              for tok in tokens:
                  if tok in ops:
                      if cur:
                          parts.append(cur)
                      cur = []
                  else:
                      cur.append(tok)
              if cur:
                  parts.append(cur)
              return parts

          def _strip_devnull_redirects(tokens):
              result, i, n = [], 0, len(tokens)
              while i < n:
                  tok = tokens[i]
                  if tok == '>' and i + 1 < n and tokens[i + 1] == '/dev/null':
                      i += 2
                      continue
                  if ((tok.isdigit() or tok == '&') and i + 2 < n
                          and tokens[i + 1] == '>' and tokens[i + 2] == '/dev/null'):
                      i += 3
                      continue
                  result.append(tok)
                  i += 1
              return result

          def _check_forbidden(tokens):
              if tokens is None:
                  return
              forbidden = set(FORBIDDEN_COMMANDS)
              for seg in _split_on(tokens, OPERATORS | {'|', '&'}):
                  while seg and seg[0] == 'command':
                      seg = seg[1:]
                  if seg and seg[0] in forbidden:
                      deny(seg[0] + " is blocked")

          def preprocess_cmd(cmd):
              parts = []
              for line in cmd.split('\n'):
                  s = line.strip()
                  if s and not s.startswith('#'):
                      parts.append(s)
              return ' ; '.join(parts)

          def is_readonly_listing(tokens):
              if tokens is None:
                  return "command could not be parsed"
              tokens = _strip_devnull_redirects(tokens)

              def _in_allowed_root(tok):
                  part = tok.split("=", 1)[-1] if "=" in tok else tok
                  normalized = os.path.normpath(os.path.expanduser(part))
                  resolved = os.path.realpath(normalized)
                  if under(resolved, cwd):
                      return True
                  if under(resolved, CLAUDE_TMP):
                      return True
                  if any(under(normalized, r) for r in NX_INPUT_ROOTS):
                      return True
                  if under(resolved, CLAUDE_HOME):
                      rel = resolved[len(CLAUDE_HOME):].lstrip(os.sep).split(os.sep)
                      if len(rel) >= 4 and rel[0] == 'projects' and rel[3] == 'tool-results':
                          return True
                      ask("access to ~/.claude requires review: " + resolved)
                  try:
                      parent = resolved if os.path.isdir(resolved) else os.path.dirname(resolved)
                      r = subprocess.run([GIT, "-C", parent, "rev-parse", "--show-toplevel"],
                                         capture_output=True, text=True, timeout=3)
                      git_root = r.stdout.strip()
                      if not git_root:
                          return False
                      git_root = os.path.realpath(git_root)
                      nxconfig_norm = os.path.realpath(NXCONFIG)
                      if under(git_root, nxconfig_norm) or git_root == nxconfig_norm:
                          return False
                      if any(under(git_root, d) or git_root == d for d in EXTRA_DIR_DENY):
                          return False
                      return under(resolved, git_root)
                  except Exception:
                      return False

              def _check_part(part):
                  if not part:
                      return "empty command segment"
                  pipe_stages = _split_on(part, {'|'})
                  if not pipe_stages or not pipe_stages[0]:
                      return "empty pipe segment"
                  lead_tokens = pipe_stages[0]
                  lead_cmd = lead_tokens[0]
                  lead = ' '.join(lead_tokens)
                  if lead_cmd != 'git' and any(tok in ('{', '}') for tok in lead_tokens):
                      return "shell metacharacter in command"
                  if lead_cmd != 'git' and any('..' in tok for tok in lead_tokens):
                      return "path traversal (..) in command"
                  if lead_cmd in ('true', 'false', 'echo'):
                      pass
                  elif lead_cmd == 'git':
                      if not re.match(r"^git(\s+(--no-pager|-C\s+\S+))*\s+(ls-files|log|status|check-ignore|diff|show|rev-parse)\b", lead):
                          return "git subcommand not in allowlist"
                      if re.search(r"(^|\s)(-c|--config|--exec-path|--git-dir|--work-tree|--namespace|--bare|--output)(=|\s|$)", lead):
                          return "git command with unsafe flags"
                      if re.search(r'\b(diff|show)\b', lead):
                          if not re.search(r"(^|\s)--no-ext-diff(\s|$)", lead):
                              if run([GIT, "-C", cwd, "config", "diff.external"], cwd):
                                  deny("diff.external is configured; add --no-ext-diff to use built-in diff")
                  elif lead_cmd == 'fd':
                      for tok in lead_tokens[1:]:
                          if tok in ('-x', '-X') or re.match(r"^(--exec|--exec-batch)(=|$)", tok):
                              return "fd with exec flag"
                          if re.match(r"^[/~]", tok) or re.search(r"=[/~]", tok):
                              resolved = os.path.normpath(os.path.expanduser(tok.split("=", 1)[-1] if "=" in tok else tok))
                              if under(resolved, "/nix/store") or resolved == "/nix/store":
                                  return "nix store traversal is blocked"
                              if not _in_allowed_root(tok):
                                  return "absolute path not under a recognised git root: " + tok
                  elif lead_cmd in READONLY_FILTERS:
                      for tok in lead_tokens[1:]:
                          if re.match(r"^[/~]", tok) or re.search(r"=[/~]", tok):
                              if not _in_allowed_root(tok):
                                  return "absolute path not under a recognised git root: " + tok
                      if lead_cmd not in GREP_FAMILY:
                          for tok in lead_tokens[1:]:
                              if re.match(r"^(-o|-O|--output|--output-file|--out-file)(=|$)", tok):
                                  return "output redirection flag in read-only command"
                      if lead_cmd == 'rg':
                          for tok in lead_tokens[1:]:
                              if re.match(r"^(--pre|--pre-glob|--hostname-bin)(=|$)", tok):
                                  return "rg with exec flag"
                      if lead_cmd == 'yq':
                          for tok in lead_tokens[1:]:
                              if re.match(r"^(-i|--in-place)(=|$)", tok):
                                  return "yq with in-place flag"
                  elif lead_cmd == 'command':
                      if len(lead_tokens) >= 2:
                          return _check_part(part[1:])
                      return "bare command builtin"
                  elif lead_cmd == 'cd':
                      if len(lead_tokens) < 2:
                          return "cd to home directory is not allowed"
                      resolved = os.path.realpath(os.path.expanduser(lead_tokens[1]))
                      if resolved == HOME:
                          return "cd to home directory is not allowed"
                      if under(resolved, CLAUDE_HOME):
                          ask("cd to ~/.claude requires review: " + resolved)
                      if not under(resolved, CLAUDE_TMP):
                          git_root = run([GIT, "-C", cwd, "rev-parse", "--show-toplevel"], cwd)
                          if not (git_root and under(resolved, os.path.realpath(git_root))):
                              return "cd to path outside current project: " + lead_tokens[1]
                  elif lead_cmd == 'nix':
                      if lead_tokens[1:3] != ['flake', 'prefetch']:
                          return "nix subcommand not in allowlist: " + ' '.join(lead_tokens[1:3])
                      for tok in lead_tokens[3:]:
                          if tok.startswith('--'):
                              continue
                          if re.match(r'^github:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)?$', tok):
                              continue
                          return "unexpected argument in nix flake prefetch: " + tok
                  elif re.match(r'^[A-Z_][A-Z0-9_]*=', lead_cmd):
                      rest = part[:]
                      env_vars = {}
                      while rest and re.match(r'^[A-Z_][A-Z0-9_]*=', rest[0]):
                          k, _, v = rest[0].partition('=')
                          env_vars[k] = v
                          rest = rest[1:]
                      if not rest:
                          return "env var with no command"
                      if rest[:3] != ['nix', 'flake', 'prefetch']:
                          return "unrecognised env-var-prefixed command: " + (rest[0] if rest else "")
                      for k, v in env_vars.items():
                          if k == 'XDG_CACHE_HOME':
                              if not (v == '/tmp' or v.startswith('/tmp/')):
                                  return "XDG_CACHE_HOME must be under /tmp: " + v
                          else:
                              return "unexpected env var for nix flake prefetch: " + k
                      for tok in rest[3:]:
                          if tok.startswith('--'):
                              continue
                          if re.match(r'^github:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)?$', tok):
                              continue
                          return "unexpected argument in nix flake prefetch: " + tok
                  elif lead_cmd == 'find':
                      for tok in lead_tokens[1:]:
                          if tok in FIND_ACTION_FLAGS:
                              return "find with side-effecting action: " + tok
                          if re.match(r"^[/~]", tok):
                              resolved = os.path.normpath(os.path.expanduser(tok))
                              if under(resolved, "/nix/store") or resolved == "/nix/store":
                                  return "nix store traversal is blocked"
                              if not _in_allowed_root(tok):
                                  return "absolute path not under a recognised git root: " + tok
                  elif lead_cmd in ('mkdir', 'rmdir'):
                      for tok in lead_tokens[1:]:
                          if tok.startswith('-'):
                              continue
                          resolved = os.path.normpath(
                              os.path.join(cwd, tok) if not os.path.isabs(tok) and not tok.startswith('~')
                              else os.path.expanduser(tok)
                          )
                          if not under(resolved, cwd):
                              return lead_cmd + " outside current directory: " + tok
                  elif lead_cmd == 'systemctl':
                      if not re.match(r"^systemctl(\s+(-[a-zA-Z]+|--[a-zA-Z0-9=-]+))*\s+(status|cat|show|is-active|is-enabled|is-failed|get-default|list-units|list-timers|list-sockets|list-jobs|list-unit-files)\b", lead):
                          return "systemctl subcommand not in allowlist"
                  elif lead_cmd == 'journalctl':
                      if re.search(r"(^|\s)(--vacuum-(size|time|files)|--rotate|--flush|--sync|--dmesg)\b", lead):
                          return "journalctl with mutating flag"
                      if re.search(r"(^|\s)-(?!-)[a-zA-Z]*k", lead):
                          return "journalctl with kernel flag"
                  else:
                      return "command not auto-allowed, review required: " + lead_cmd
                  for stage in pipe_stages[1:]:
                      if not stage:
                          return "empty pipe segment"
                      tool = stage[0]
                      if tool not in READONLY_FILTERS:
                          return "pipe filter not auto-allowed, review required: " + tool
                      for tok in stage[1:]:
                          if tok in ('{', '}'):
                              return "shell metacharacter in command"
                          if '..' in tok:
                              return "path traversal (..) in command"
                          if re.match(r"^[/~]", tok) or re.search(r"=[/~]", tok):
                              if not _in_allowed_root(tok):
                                  return "absolute path not under a recognised git root: " + tok
                      if tool not in GREP_FAMILY:
                          for tok in stage[1:]:
                              if re.match(r"^(-o|-O|--output|--output-file|--out-file)(=|$)", tok):
                                  return "output redirection flag in read-only command"
                      if tool == 'rg':
                          for tok in stage[1:]:
                              if re.match(r"^(--pre|--pre-glob|--hostname-bin)(=|$)", tok):
                                  return "rg with exec flag"
                      if tool == 'yq':
                          for tok in stage[1:]:
                              if re.match(r"^(-i|--in-place)(=|$)", tok):
                                  return "yq with in-place flag"
                  return None

              BLOCKING_TOKENS = frozenset(['<', '>', '`', '(', ')', '&', '$'])
              for tok in tokens:
                  if tok in OPERATORS or tok == '|':
                      continue
                  if tok in BLOCKING_TOKENS:
                      return "shell metacharacter in command"
              for part in _split_on(tokens, OPERATORS):
                  reason = _check_part(part)
                  if reason is not None:
                      return reason
              return None

          data = load(strict=True)

          cwd = data.get("cwd") or os.getcwd()
          path = tool_path(data)
          cmd = tool_input(data).get("command") or ""
          url = tool_input(data).get("url") or ""
          tool_name = data.get("tool_name") or ""

          BAKED_WEB_DOMAINS = set(${builtins.toJSON bakedWebDomains})
          ALLOWED_WEB_PATTERNS = ${builtins.toJSON config.nx.common.dev.claude.allowedWebFetchDomains}

          ${forkDenyBlock}
          ${nestedDenyBlock}
          if tool_name == "WebSearch":
              query = tool_input(data).get("query") or ""
              if re.search(r"/\.config/nx/nxconfig|\.\./nxconfig", query):
                  ask("WebSearch query references nxconfig: " + query)
              if SECRET_FILE.search(query):
                  ask("WebSearch query contains a secret file path: " + query)
              allow("WebSearch")

          if tool_name == "WebFetch" and url:
              try:
                  from urllib.parse import urlparse
                  domain = urlparse(url).netloc.lower()
                  if domain.startswith("www."):
                      domain = domain[4:]
              except Exception:
                  domain = ""
              if domain and (domain in BAKED_WEB_DOMAINS or any(re.search(p, domain) for p in ALLOWED_WEB_PATTERNS)):
                  allow("WebFetch to allowed domain: " + domain)
              else:
                  ask("WebFetch to unrecognised domain: " + domain)

          if path:
              target = resolve(cwd, path)
              if under(target, NXCONFIG) and not nxconfig_allowed(target):
                  deny("access to nxconfig is off-limits: " + target)
              if tool_name == "Read" and any(under(target, r) for r in NX_INPUT_ROOTS):
                  allow("read from nx inputs")
              if any(under(target, d) for d in EXTRA_DIR_DENY):
                  if tool_name == "Read" and under(target, "/nix/store"):
                      ask("reading from nix store: " + target)
                  deny("access to disallowed directory: " + target)
              if any(under(target, secret) for secret in SECRET_DIRS):
                  deny("access to secret material is blocked: " + target)
              if SECRET_FILE.search(target):
                  deny("access to secret material is blocked: " + target)
              for pattern in EXTRA_PATH_DENY:
                  if re.search(pattern, target):
                      deny("path denied by guardrailDisallowedPaths: " + target)
              if tool_name == "Read":
                  real_target = os.path.realpath(target)
                  cwd_root = run([GIT, "-C", cwd, "rev-parse", "--show-toplevel"], cwd)
                  if cwd_root and under(real_target, os.path.realpath(cwd_root)):
                      allow("read within project")
                  try:
                      parent = real_target if os.path.isdir(real_target) else os.path.dirname(real_target)
                      r = subprocess.run([GIT, "-C", parent, "rev-parse", "--show-toplevel"],
                                         capture_output=True, text=True, timeout=3)
                      raw = r.stdout.strip()
                      if raw:
                          git_root = os.path.realpath(raw)
                          nxconfig_norm = os.path.realpath(NXCONFIG)
                          if not (under(git_root, nxconfig_norm) or git_root == nxconfig_norm):
                              if not any(under(git_root, d) or git_root == d for d in EXTRA_DIR_DENY):
                                  allow("read within git repo")
                  except Exception:
                      pass

          if cmd:
              for pattern in EXTRA_CMD_DENY:
                  if re.search(pattern, cmd):
                      deny("command denied by guardrailDisallowedCommands")
              cmd = preprocess_cmd(cmd)
              tokens = _tokenize(cmd)
              _check_forbidden(tokens)
              if re.search(r"(^|[;&|()\s])rm\s", cmd) and re.search(r"-\w*r\w*f|-\w*f\w*r|-r\b.*-f\b|-f\b.*-r\b", cmd):
                  deny("rm -rf is blocked; use individual rm per file and rmdir for empty directories")
              if re.search(r"\bgit\b.*\bpush\b", cmd) and re.search(r"(--force(\W|$)|\s-f(\s|$))", cmd) and not re.search(r"--force-with-lease", cmd):
                  deny("git push --force is blocked")
              if re.search(r"\bgit\b.*\b(commit|push|pull|fetch)\b", cmd):
                  deny("git commit, push, pull and fetch are blocked")
              if re.search(r"(^|[;&|()\s])(ssh|scp|rsync)\b(?!-)", cmd):
                  deny("ssh, scp and rsync are blocked")
              if re.search(r"\bdd\s.*of=/dev/", cmd):
                  deny("writing with dd to a block device is blocked")
              if re.search(r"(curl|wget)[^|]*\|[^|]*(sh|bash|python3?|perl|ruby|node)", cmd):
                  deny("piping a download into a shell or interpreter is blocked")
              if re.search(r"/\.config/nx/nxconfig|\.\./nxconfig", cmd) and not re.search(r"\.md(\W|$)|flake\.nix|flake\.lock", cmd):
                  deny("referencing nxconfig from a shell command is blocked")
              reason = is_readonly_listing(tokens)
              if reason is None:
                  allow("read-only file listing")
              AUTO_DENY_REASONS = ${builtins.toJSON autoDenyReasons}
              if reason and any(reason.startswith(p) for p in AUTO_DENY_REASONS):
                  deny(reason)
              if re.search(r"(?<!\|)\|(?!\|)", cmd):
                  ask(reason or "this command contains a pipe, review it before allowing")
              if reason:
                  ask(reason)
        '';

        contextBody = ''
          data = load()
          event = data.get("hook_event_name") or "SessionStart"
          cwd = data.get("cwd") or os.getcwd()

          sections = ["Session context (auto-injected):\nDate: " + datetime.now().strftime("%Y-%m-%d %H:%M")]

          if run([GIT, "-C", cwd, "rev-parse", "--is-inside-work-tree"], cwd) == "true":
              git_lines = ["Branch: " + run([GIT, "-C", cwd, "branch", "--show-current"], cwd)]
              status = run([GIT, "-C", cwd, "status", "--porcelain"], cwd)
              if status:
                  git_lines.append(status)
              sections.append("\n".join(git_lines))

          if event != "PostCompact":
              full = full_files(cwd)
              if full is not None and len(full) <= 3500:
                  sections.append("Project files (COMPLETE list of every file, full paths, dotfiles excluded):\n" + full)
              else:
                  sections.append("Project directories (COMPLETE list of every dir containing files, dotfiles excluded):\n" + project_tree(cwd))
                  sections.append("Files in the top two levels only (repo root and one level deep; this is NOT the full file list, deeper files are omitted, use the directory list above to locate them):\n" + shallow_files(cwd))

          last = pointer_path(data.get("session_id"))
          if event == "PostCompact" and os.path.isfile(last):
              with open(last) as handle:
                  sections.append("Pre-compact transcript snapshot: " + handle.read().strip())

          context("\n\n".join(sections), event)
        '';

        precompactBody = ''
          data = load()
          snapshot(data.get("transcript_path"), data.get("session_id"))
        '';

        notifyCmd = self.notifyUser {
          inherit pkgs;
          title = "Claude Code";
          body = "$NX_CLAUDE_MSG";
          icon = "computer";
          urgency = "normal";
        };

        notifyBody = ''
          NOTIFY_CMD = ${builtins.toJSON notifyCmd}

          SUPPRESSED_MESSAGES = set(${builtins.toJSON suppressedNotifications})

          data = load()
          message = data.get("message") or ""
          if not message:
              sys.exit(0)
          if message in SUPPRESSED_MESSAGES:
              sys.exit(0)

          subprocess.run(NOTIFY_CMD, shell=True, env=dict(os.environ, NX_CLAUDE_MSG=message))
        '';

        mkPythonHook =
          name: body:
          pkgs.writers.writePython3 name {
            flakeIgnore = [
              "E501"
              "E302"
              "E305"
              "E128"
              "E131"
              "E231"
              "W503"
            ];
          } (pythonHookLib + "\n" + body);

        guardrailScript = mkPythonHook "nx-claude-guardrail" guardrailBody;
        contextInjectScript = mkPythonHook "nx-claude-context" contextBody;
        precompactScript = mkPythonHook "nx-claude-precompact" precompactBody;
        notifyScript = mkPythonHook "nx-claude-notify" notifyBody;

        rawDefaultHookHandlers = {
          PreToolUse = {
            command = guardrailScript;
          };
          SessionStart = {
            command = contextInjectScript;
          };
          PostCompact = {
            command = contextInjectScript;
          };
          PreCompact = {
            command = precompactScript;
          };
          Notification = {
            command = notifyScript;
          };
        };
        defaultHookHandlers = lib.mapAttrs (_event: lib.mkDefault) rawDefaultHookHandlers;
      in
      {
        nx.common.dev.claude.hookHandlers =
          lib.mkIf config.nx.common.dev.claude.enableDefaultHookHandlers defaultHookHandlers;

        nx.common.dev.agents.enabledAgents = [ "claude" ];
        nx.common.dev.agents.preferredAgent = lib.mkDefault "claude";

        nx.common.dev.claude.instructions = lib.mkOrder 200 baseInstructions;

        nx.common.dev.claude.skills = lib.mkOrder 200 baseSkills;
        nx.common.dev.claude.agents = lib.mkOrder 200 baseAgents;

        nx.common.git.git.globalIgnores = [
          "CLAUDE.md"
          ".claude"
        ];

        nx.common.dev.claude.guardrailDisallowedDirectories = [
          "/nix/store"
          "/dev"
          "/etc"
          "/usr"
          "/var"
        ];
      };

    home =
      {
        config,
        instructions,
        skills,
        agents,
        autoCompact,
        autoCompactWindow,
        autoCompactPercent,
        contextWarnPercent,
        style,
        model,
        modelVersions,
        effortLevel,
        notifyEnabled,
        alwaysThinkingEnabled,
        fileCheckpointingEnabled,
        disableWorkflows,
        enableArtifact,
        editorMode,
        askUserQuestionTimeout,
        spinnerTipsEnabled,
        awaySummaryEnabled,
        autoScrollEnabled,
        remoteControlAtStartup,
        permissionMode,
        useAutoModeDuringPlan,
        voiceModeEnabled,
        defaultVoiceMode,
        sounds,
        delegateToSubagents,
        allowNestedSubagents,
        ...
      }:
      let
        sharedAgents = config.nx.common.dev.agents;
        tc = config.nx.preferences.theme.colors;
        ansi = color: helpers.hexToAnsiRgb color.html;

        renderMerged = self.common.dev.agents.exports.renderMerged;
        renderPrograms = self.common.dev.agents.exports.renderPrograms;

        mergedContext = renderMerged [
          sharedAgents.instructions
          instructions
          (renderPrograms sharedAgents.programs)
        ];
        styleText = renderMerged [
          sharedAgents.style
          style
        ];
        styleEnabled = styleText != "";

        mergedSkills = sharedAgents.skills // skills;

        mergedAgents = sharedAgents.agents // agents;

        compactWindowValue = if autoCompactWindow == null then "" else builtins.toString autoCompactWindow;
        compactPercentValue = builtins.toString (
          if autoCompactPercent == null then 100 else autoCompactPercent
        );

        nxOutputStyle = ''
          ---
          name: nx
          description: Personality and response style rules from the nx agent configuration.
          keep-coding-instructions: true
          ---

          ${styleText}
        '';

        gitUrl = (config.programs.git.settings.url or { });
        githubEnforceSSH =
          gitUrl ? "git@github.com:"
          && (
            let
              entry = gitUrl."git@github.com:";
              insteadOf = entry.insteadOf or null;
            in
            if lib.isList insteadOf then
              lib.any (v: lib.hasPrefix "https://github.com/" v) insteadOf
            else
              lib.isString insteadOf && lib.hasPrefix "https://github.com/" insteadOf
          );

        fake-ssh = pkgs.writeShellScriptBin "ssh" "exit 1";

        sshWrapperArgs = lib.optionals (githubEnforceSSH && config.nx.linux.security.yubikey.enable) [
          "--prefix PATH : ${fake-ssh}/bin"
          "--set GIT_CONFIG_COUNT 1"
          ''--set GIT_CONFIG_KEY_0 "url.https://github.com/.insteadOf"''
          ''--set GIT_CONFIG_VALUE_0 "git@github.com:"''
        ];
        autoCompactWrapperArgs =
          lib.optional (
            autoCompactWindow != null
          ) "--set CLAUDE_CODE_AUTO_COMPACT_WINDOW ${builtins.toString autoCompactWindow}"
          ++ lib.optional (
            autoCompactPercent != null
          ) "--set CLAUDE_AUTOCOMPACT_PCT_OVERRIDE ${builtins.toString autoCompactPercent}";
        modelVersionWrapperArgs = lib.mapAttrsToList (
          alias: versions:
          let
            version = if modelVersions.${alias} == null then lib.head versions else modelVersions.${alias};
          in
          "--set ${modelAliasEnvVars.${alias}} ${modelIdFor alias version}"
        ) modelVersionsByAlias;
        claudeWrapperArgs = sshWrapperArgs ++ autoCompactWrapperArgs ++ modelVersionWrapperArgs;

        claude-code-wrapped = pkgs.symlinkJoin {
          name = "claude-code-wrapped";
          paths = [ pkgs.claude-code ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/claude ${lib.concatStringsSep " " claudeWrapperArgs}
          '';
        };
        claude-package = if claudeWrapperArgs != [ ] then claude-code-wrapped else pkgs.claude-code;

        statusline-command = pkgs.writeShellScript "statusline-command" ''
          input=$(cat)

          ctx_pct=""
          ctx_warn_tokens=""
          model_window=""
          five_h=""
          five_h_reset=""
          week=""
          week_reset=""
          cost=""
          tokens=""
          exceeds="false"
          if command -v jq >/dev/null 2>&1; then
            model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
            dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')
            ctx_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty' | cut -d. -f1)
            five_h=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
            five_h_reset=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
            week=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
            week_reset=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
            exceeds=$(printf '%s' "$input" | jq -r '.exceeds_200k_tokens // false')
            tokens=$(printf '%s' "$input" | jq -r '.context_window.total_input_tokens // empty')
            cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')
            model_window=$(printf '%s' "$input" | jq -r '
              if ((.context_window.used_percentage // 0) > 0) and ((.context_window.total_input_tokens // 0) > 0)
              then (.context_window.total_input_tokens * 100 / .context_window.used_percentage / 1000 | ceil) * 1000
              else empty end')
          else
            model="Claude"
            dir=""
          fi

          [ -z "$dir" ] && dir="$PWD"

          case "$dir" in
            "$HOME") disp_dir="~" ;;
            "$HOME"/*) disp_dir="~''${dir#"$HOME"}" ;;
            *) disp_dir="$dir" ;;
          esac

          branch=""
          if git -C "$dir" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
            repo_root=$(git -C "$dir" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
            [ -n "$repo_root" ] && disp_dir=$(basename "$repo_root")
          fi

          SEP=""
          CAP_L=""
          CAP_R=""
          SEP_DIM=""

          INK='${ansi tc.main.backgrounds.primary}'
          BG='${ansi tc.main.backgrounds.primary}'

          DIR_BG='${ansi tc.blocks.primary.foreground}'

          MODEL_DEF='${ansi tc.blocks.critical.foreground}'
          MODEL_HAIKU='${ansi tc.blocks.info.foreground}'
          MODEL_SONNET='${ansi tc.blocks.neutral.foreground}'
          MODEL_OPUS='${ansi tc.blocks.highlight.foreground}'
          MODEL_FABLE='${ansi tc.blocks.warning.foreground}'

          BODY_BG='${ansi tc.terminal.normalBackgrounds.secondary}'
          BODY_FG='${ansi tc.terminal.foregrounds.primary}'
          DIM_FG='${ansi tc.terminal.foregrounds.dim}'
          LBL_FG='${ansi tc.terminal.foregrounds.secondary}'
          VAL_FG='${ansi tc.terminal.foregrounds.primary}'

          ERR_BG='${ansi tc.semantic.error}'
          WARN_BG='${ansi tc.semantic.warning}'

          prev_bg=""

          sep() {
            if [ -n "$2" ]; then
              printf '\033[48;2;%sm' "$2"
            else
              printf '\033[48;2;%sm' "$BG"
            fi
            printf '\033[38;2;%sm%s' "$1" "$SEP"
          }

          segment() {
            if [ -n "$prev_bg" ]; then
              if [ "$prev_bg" = "$2" ]; then
                printf '\033[48;2;%sm\033[38;2;%sm%s' "$2" "$1" "$SEP_DIM"
              else
                sep "$prev_bg" "$2"
              fi
            else
              printf '\033[48;2;%sm\033[38;2;%sm\033[7m%s\033[27m\033[48;2;%sm' "$BG" "$2" "$CAP_L" "$2"
            fi
            printf '\033[38;2;%sm %s ' "$1" "$3"
            prev_bg="$2"
          }

          end_segments() {
            printf '\033[0m\033[48;2;%sm\033[38;2;%sm%s\033[0m' "$BG" "$prev_bg" "$CAP_R"
          }

          fmt_reset() {
            now=$(date +%s)
            remaining=$(( $1 - now ))
            [ "$remaining" -lt 0 ] && remaining=0
            d=$(( remaining / 86400 ))
            h=$(( (remaining % 86400) / 3600 ))
            m=$(( (remaining % 3600) / 60 ))
            if [ "$d" -gt 0 ]; then
              printf '%dd%dh%dm' "$d" "$h" "$m"
            else
              printf '%dh%dm' "$h" "$m"
            fi
          }

          model_bg="$MODEL_DEF"
          case "$model" in
            *Haiku*)  model_bg="$MODEL_HAIKU" ;;
            *Sonnet*) model_bg="$MODEL_SONNET" ;;
            *Opus*)   model_bg="$MODEL_OPUS" ;;
            *Fable*)  model_bg="$MODEL_FABLE" ;;
          esac

          COMPACT_WINDOW='${compactWindowValue}'
          COMPACT_PCT='${compactPercentValue}'
          WARN_PCT='${builtins.toString contextWarnPercent}'
          AUTO_COMPACT_ENABLED='${lib.boolToString autoCompact}'

          if [ -n "$tokens" ] && { [ -n "$COMPACT_WINDOW" ] || [ -n "$model_window" ]; }; then
            eff_window="$COMPACT_WINDOW"
            if [ -n "$model_window" ] && [ "$model_window" -gt 0 ]; then
              if [ -z "$eff_window" ] || [ "$model_window" -lt "$eff_window" ]; then
                eff_window="$model_window"
              fi
            fi
            if [ "$AUTO_COMPACT_ENABLED" = "true" ]; then
              threshold_tokens=$(( eff_window * COMPACT_PCT / 100 ))
              ctx_warn_tokens=$(( eff_window * COMPACT_PCT * WARN_PCT / 10000 ))
            else
              threshold_tokens="$eff_window"
              ctx_warn_tokens=$(( eff_window * WARN_PCT / 100 ))
            fi
            [ "$threshold_tokens" -gt 0 ] && ctx_pct=$(( tokens * 100 / threshold_tokens ))
          fi

          ctx_alert=0
          if [ -n "$ctx_warn_tokens" ]; then
            [ "$tokens" -ge "$ctx_warn_tokens" ] && ctx_alert=1
          else
            [ -n "$ctx_pct" ] && [ "$ctx_pct" -gt "$WARN_PCT" ] && ctx_alert=1
          fi

          ctx_fg="$VAL_FG"; ctx_bg="$BODY_BG"
          [ "$ctx_alert" = 1 ] && { ctx_fg="$INK"; ctx_bg="$ERR_BG"; }
          five_h_fg="$VAL_FG"; five_h_bg="$BODY_BG"
          [ -n "$five_h" ] && [ "$five_h" -gt 50 ] && { five_h_fg="$INK"; five_h_bg="$ERR_BG"; }
          week_fg="$VAL_FG"; week_bg="$BODY_BG"
          [ -n "$week" ] && [ "$week" -gt 75 ] && { week_fg="$INK"; week_bg="$ERR_BG"; }

          segment "$INK" "$DIR_BG" "$disp_dir"
          [ -n "$branch" ] && segment "$BODY_FG" "$BODY_BG" "$branch"
          segment "$INK" "$model_bg" "$model"
          [ -n "$cost" ] && segment "$DIM_FG" "$BODY_BG" "$(printf '$%.2f' "$cost")"
          if [ -n "$ctx_pct" ]; then
            segment "$LBL_FG" "$BODY_BG" "Context"
            segment "$ctx_fg" "$ctx_bg" "$(printf '%2s' "$ctx_pct")%"
          fi
          if [ -n "$five_h" ]; then
            segment "$LBL_FG" "$BODY_BG" "Session"
            five_h_label="$(printf '%2s' "$five_h")%"
            [ -n "$five_h_reset" ] && five_h_label="$five_h_label · $(fmt_reset "$five_h_reset")"
            segment "$five_h_fg" "$five_h_bg" "$five_h_label"
          fi
          if [ -n "$week" ]; then
            segment "$LBL_FG" "$BODY_BG" "Week"
            week_label="$(printf '%2s' "$week")%"
            [ -n "$week_reset" ] && week_label="$week_label · $(fmt_reset "$week_reset")"
            segment "$week_fg" "$week_bg" "$week_label"
          fi
          tokens_fg="$VAL_FG"; tokens_bg="$BODY_BG"
          if [ "$ctx_alert" = 1 ]; then
            tokens_fg="$INK"; tokens_bg="$ERR_BG"
          elif [ "$exceeds" = "true" ]; then
            tokens_fg="$INK"; tokens_bg="$WARN_BG"
          fi
          if [ -n "$tokens" ]; then
            tokens_label="$((tokens / 1000))k tokens used"
          else
            tokens_label="<200k tokens used"
            [ "$exceeds" = "true" ] && tokens_label=">200k tokens used"
          fi
          segment "$tokens_fg" "$tokens_bg" "$tokens_label"
          end_segments
          printf '\n'
        '';

        hookHandlers = config.nx.common.dev.claude.hookHandlers;
        renderedHooks = lib.filterAttrs (_event: entries: entries != [ ]) (
          lib.mapAttrs (
            _event: handler:
            lib.optional (handler != null && handler.enable) (
              lib.optionalAttrs (handler.matcher != null) { matcher = handler.matcher; }
              // {
                hooks = [
                  {
                    type = "command";
                    command = builtins.toString handler.command;
                  }
                ];
              }
            )
          ) hookHandlers
        );

        soundFileMap = {
          Stop = "message-new-instant.oga";
          StopFailure = "dialog-warning.oga";
          Notification = "dialog-information.oga";
          PermissionRequest = "dialog-information.oga";
          PermissionDenied = "dialog-warning.oga";
          PostToolUseFailure = "dialog-warning.oga";
          TaskCompleted = "message-new-instant.oga";
          PreCompact = "dialog-information.oga";
          PostCompact = "message-new-instant.oga";
          Elicitation = "dialog-information.oga";
        };

        resolvedSoundSink =
          if sounds.sink == null || !self.isLinux then
            null
          else
            let
              pipewireCfg = config.nx.linux.sound.pipewire;
            in
            if sounds.sink == "headset" then pipewireCfg.headsetSinkID else pipewireCfg.speakerSinkID;

        soundHookSuppressedMessages = {
          Notification = suppressedNotifications;
        };

        mkSoundScript =
          file: suppressed:
          let
            soundPath =
              helpers.packageFile args pkgs.sound-theme-freedesktop
                "share/sounds/freedesktop/stereo/${file}";
            name = "nx-claude-sound-${lib.removeSuffix ".oga" file}";
            playArgs =
              if self.isLinux then
                [ "${pkgs.pipewire}/bin/pw-play" ]
                ++ lib.optionals (resolvedSoundSink != null) [
                  "--target"
                  resolvedSoundSink
                ]
                ++ [ soundPath ]
              else
                [
                  "${pkgs.sox}/bin/play"
                  "-q"
                  soundPath
                ];
          in
          if suppressed == [ ] then
            pkgs.writeShellScript name ''
              exec ${lib.escapeShellArgs playArgs}
            ''
          else
            pkgs.writers.writePython3 name
              {
                flakeIgnore = [
                  "E501"
                  "E302"
                  "E305"
                  "E231"
                  "E401"
                ];
              }
              ''
                import json, subprocess, sys
                data = json.loads(sys.stdin.read() or "{}")
                if (data.get("message") or "") in set(${builtins.toJSON suppressed}):
                    sys.exit(0)
                subprocess.run(${builtins.toJSON playArgs})
              '';

        activeSoundHooks = lib.optionalAttrs sounds.enable (
          lib.filterAttrs (event: _: sounds.hooks.${event}) soundFileMap
        );

        soundHookEntries = lib.mapAttrs (
          event: file:
          let
            suppressed = soundHookSuppressedMessages.${event} or [ ];
          in
          [
            {
              hooks = [
                {
                  type = "command";
                  command = builtins.toString (mkSoundScript file suppressed);
                }
              ];
            }
          ]
        ) activeSoundHooks;

        subagentStartParts = [
          (
            "You are a subagent. Your work should be self-contained and drive toward a conclusion without user interaction."
            + lib.optionalString (!allowNestedSubagents) " You may not spawn further subagents yourself."
          )
        ]
        ++ lib.optional delegateToSubagents (
          lib.concatStringsSep "\n" [
            "Communicating with the main agent via SendMessage to \"main\":"
            "- Progress updates or findings: send and continue working. Do not wait for a reply."
            "- Blocking uncertainty you cannot resolve alone: send and wait. The main agent will reply to unblock you."
          ]
        )
        ++ lib.optional styleEnabled ("Output style (nx):\n\n" + styleText);

        subagentStartContext = lib.concatStringsSep "\n\n" subagentStartParts;

        subagentStartScript =
          pkgs.writers.writePython3 "nx-claude-subagent-start"
            {
              flakeIgnore = [
                "E501"
                "E302"
                "E305"
              ];
            }
            ''
              import json
              import sys
              json.dump({"hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": ${builtins.toJSON subagentStartContext}}}, sys.stdout)
              sys.exit(0)
            '';

        subagentStartHookEntries = {
          SubagentStart = [
            {
              hooks = [
                {
                  type = "command";
                  command = builtins.toString subagentStartScript;
                }
              ];
            }
          ];
        };

        allHookEvents = lib.unique (
          lib.attrNames renderedHooks
          ++ lib.attrNames soundHookEntries
          ++ lib.attrNames subagentStartHookEntries
        );
        mergedHooks = lib.filterAttrs (_: v: v != [ ]) (
          lib.genAttrs allHookEvents (
            event:
            (soundHookEntries.${event} or [ ])
            ++ (renderedHooks.${event} or [ ])
            ++ (subagentStartHookEntries.${event} or [ ])
          )
        );
      in
      {
        programs.claude-code = {
          enable = true;
          package = claude-package;
          enableMcpIntegration = true;
          context = mergedContext;
          settings = {
            tui = "fullscreen";
            statusLine = {
              type = "command";
              command = "${statusline-command}";
            };
            autoCompactEnabled = autoCompact;
            inherit model effortLevel;
            agentPushNotifEnabled = notifyEnabled;
            preferredNotifChannel = "notifications_disabled";
            outputStyle = if styleEnabled then "nx" else "default";
            inherit
              alwaysThinkingEnabled
              fileCheckpointingEnabled
              disableWorkflows
              enableArtifact
              ;
            inherit editorMode askUserQuestionTimeout;
            inherit spinnerTipsEnabled awaySummaryEnabled autoScrollEnabled;
            inherit remoteControlAtStartup useAutoModeDuringPlan;
            permissions.defaultMode = permissionMode;
          }
          // lib.optionalAttrs (mergedHooks != { }) {
            hooks = mergedHooks;
          }
          // lib.optionalAttrs voiceModeEnabled {
            voice = {
              enabled = true;
              mode = defaultVoiceMode;
            };
          };
          skills = lib.mapAttrs (
            name: value:
            let
              payload =
                if lib.isString value then
                  {
                    description = "Custom skill ${name}.";
                    text = value;
                  }
                else
                  {
                    description = value.description or "Custom skill ${name}.";
                    text = value.text;
                  };
            in
            ''
              ---
              name: ${builtins.toJSON name}
              description: ${builtins.toJSON payload.description}
              ---

              ${payload.text}
            ''
          ) mergedSkills;
          agents = lib.mapAttrs (
            name: value:
            let
              desc = value.description or "Custom agent ${name}.";
              toolsLine = lib.concatStringsSep ", " value.tools;
            in
            ''
              ---
              name: ${builtins.toJSON name}
              description: ${builtins.toJSON desc}
              tools: ${toolsLine}
              ---

              # ${name}

              ${value.text}
            ''
          ) mergedAgents;
          outputStyles = lib.mkIf styleEnabled { nx = nxOutputStyle; };
        };

        home = {
          file =
            lib.optionalAttrs (self.isModuleEnabled "emacs.doom") {
              ".config/doom/config/80-claude.el".text = ''
                (use-package claude-code-ide
                  :bind ("C-c '" . claude-code-ide-menu)
                  :config
                  (claude-code-ide-emacs-tools-setup)
                  (setq claude-code-ide-terminal-backend 'eat))
              '';

              ".config/doom/packages/80-claude.el".text = ''
                (package! claude-code-ide
                  :recipe (:host github :repo "manzaltu/claude-code-ide.el" :files ("*.el")))
              '';
            }
            // lib.optionalAttrs voiceModeEnabled {
              ".claude/keybindings.json".text = builtins.toJSON {
                "bindings" =
                  let
                    voiceModeKeyBind = if defaultVoiceMode == "tap" then "space" else "meta+s";
                  in
                  [
                    {
                      "context" = "Chat";
                      "bindings" = {
                        ${voiceModeKeyBind} = "voice:pushToTalk";
                      };
                    }
                  ];
              };
            };

          persistence."${self.persist}" = {
            directories = [
              ".claude"
            ];
            files = [
              ".claude.json"
            ];
          };
        };

        programs.nixvim = lib.mkIf (self.isModuleEnabled "nvim.nixvim") {
          extraPlugins = [
            (pkgs.vimUtils.buildVimPlugin {
              pname = "claude-code-nvim";
              version = "c9a31e5";
              src = pkgs.fetchFromGitHub {
                owner = "greggh";
                repo = "claude-code.nvim";
                rev = "c9a31e51069977edaad9560473b5d031fcc5d38b";
                hash = "sha256-ZEIPutxhgyaAhq+fJw1lTO781IdjTXbjKy5yKgqSLjM=";
              };
              dependencies = with pkgs.vimPlugins; [ plenary-nvim ];
            })
          ];

          plugins.which-key.settings.spec = lib.mkIf (self.common.isModuleEnabled "nvim-modules.which-key") [
            {
              __unkeyed-1 = "<leader>cc";
              desc = "Toggle Claude Code";
              icon = "🤖";
            }
          ];

          extraConfigLua = lib.mkIf (self.isModuleEnabled "nvim.nixvim") ''
            _G.nx_modules = _G.nx_modules or {}
            _G.nx_modules["90-claude-code"] = function()
              require('claude-code').setup({
                window = {
                  position = "botright",
                  split_ratio = 0.4,
                },
              })

              vim.keymap.set('n', '<leader>cc', '<cmd>ClaudeCode<CR>', {
                desc = 'Toggle Claude Code',
                silent = true
              })
            end
          '';
        };
      };
  };
}
