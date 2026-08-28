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
    opus = "4.6";
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
    "Notification"
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
            model = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.enum [
                  "haiku"
                  "sonnet"
                  "opus"
                  "fable"
                ]
              );
              default = null;
              description = "Model override for this agent, null uses the session default.";
            };
            effort = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.enum [
                  "low"
                  "medium"
                  "high"
                  "xhigh"
                  "max"
                ]
              );
              default = null;
              description = "Effort level override for this agent, null inherits from the session.";
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
      default = "sonnet";
      description = "Model for spawned subagents, null uses the main session model with no override.";
    };

    maxConcurrentSubagents = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Maximum number of subagents to run concurrently when delegation is enabled.";
    };

    subagentEffortLevel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "low"
          "medium"
          "high"
          "xhigh"
          "max"
        ]
      );
      default = "medium";
      description = "Effort level for the built-in general-purpose subagent wrapper, null inherits the session effort.";
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
      default = "subagent";
      description = "Default agent type Claude spawns for general subagent work.";
    };

    webSearchAgentModel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "haiku"
          "sonnet"
          "opus"
          "fable"
        ]
      );
      default = "haiku";
      description = "Model for the built-in web search agent, null disables the agent.";
    };

    webSearchAgentEffortLevel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "low"
          "medium"
          "high"
          "xhigh"
          "max"
        ]
      );
      default = "low";
      description = "Effort level for the built-in web search agent.";
    };

    reviewAgentModel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "haiku"
          "sonnet"
          "opus"
          "fable"
        ]
      );
      default = "opus";
      description = "Model for the built-in code review agent, null disables the agent.";
    };

    reviewAgentEffortLevel = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "low"
          "medium"
          "high"
          "xhigh"
          "max"
        ]
      );
      default = "high";
      description = "Effort level for the built-in code review agent.";
    };

    enableBuiltinCodeReview = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow the built-in /code-review and /simplify commands, when false the guardrail hard-denies them in favour of the injected review skills.";
    };

    styleReminderInterval = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 10;
      description = "Inject a style reminder every N user prompt turns, null disables it.";
    };

    claudeMdReminderInterval = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 20;
      description = "Re-inject the global CLAUDE.md every N user prompt turns and after compaction, null disables it.";
    };

    recentMessagesOnCompact = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 3000;
      description = "Maximum characters of recent message pairs to re-inject after compaction, null disables.";
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

    guardrailAllowedEnvVars = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra environment variable names the guardrail expands before path checks, so $VAR and $VAR/... in Bash commands resolve to real paths and are checked against allowed roots instead of being blocked.";
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
        webSearchModel = config.nx.common.dev.claude.webSearchAgentModel;
        webSearchEffortLevel = config.nx.common.dev.claude.webSearchAgentEffortLevel;
        reviewModel = config.nx.common.dev.claude.reviewAgentModel;
        reviewEffortLevel = config.nx.common.dev.claude.reviewAgentEffortLevel;
        subagentEffortLevel = config.nx.common.dev.claude.subagentEffortLevel;
        builtinCodeReviewEnabled = config.nx.common.dev.claude.enableBuiltinCodeReview;
        ripgrepEnabled = config.nx.common.shell.rust-programs.enable or false;
        styleReminderInterval = config.nx.common.dev.claude.styleReminderInterval;
        claudeMdReminderInterval = config.nx.common.dev.claude.claudeMdReminderInterval;
        recentMessagesOnCompact = config.nx.common.dev.claude.recentMessagesOnCompact;
        renderMerged = self.common.dev.agents.exports.renderMerged;
        agentsModule = config.nx.common.dev.agents;
        styleText = renderMerged [
          agentsModule.style
          config.nx.common.dev.claude.style
        ];
        baseInstructions = {
          "90 - Claude" =
          [
            "Use the conversation as initial context, then read only the files and local context required to complete the request."
            "Batch all changes into as few operations as possible."
            "Don't analyse too much on first feasibility questions to avoid wasting tokens."
            "If a background event (task notification, agent message, command result) triggers a turn but you have already reported everything relevant to the user in a prior response this session, run Bash 'true' as a no-op instead of repeating yourself. Use description: 'Background task completed' on the Bash call. Do not also write text; the no-op is the entire response."
            "If a tool call fails only because its approval could not be delivered (a transient approval-path error asking to try again, never a nonzero exit code or other tool error), silently reissue it up to three times before telling the user, and do not print that message."
            (
              if ripgrepEnabled then
                "Make all file writes and edits with the Edit or Write tool. For printing or slicing lines, prefer head, tail, rg, or cat: the guardrail auto-allows them, while sed and awk are not auto-allowed and only trigger a prompt."
              else
                "Make all file writes and edits with the Edit or Write tool. For printing or slicing lines, prefer head, tail, or cat: the guardrail auto-allows them, while sed and awk are not auto-allowed and only trigger a prompt."
            )
            (
              if ripgrepEnabled then
                "Under the agents plans directory (NX_AGENTS_PLANS_DIR), read plan files with the Read tool and create or change their contents only with the Write and Edit tools, never with sed or shell redirection. Read-only shell commands (ls, rg, grep, cat) are allowed there, for example to find still-open plans. mv and rm are allowed only when every path stays inside the plans directory, for example to archive a finished plan into the archive subdirectory or remove a stale one. Do not run other mutating shell commands against plan files."
              else
                "Under the agents plans directory (NX_AGENTS_PLANS_DIR), read plan files with the Read tool and create or change their contents only with the Write and Edit tools, never with sed or shell redirection. Read-only shell commands (ls, grep, cat) are allowed there, for example to find still-open plans. mv and rm are allowed only when every path stays inside the plans directory, for example to archive a finished plan into the archive subdirectory or remove a stale one. Do not run other mutating shell commands against plan files."
            )
            [
              "When asked to look at or modify .nix source files, find them in the current git repository, never in deployed files."
              "When asked to investigate or change how Claude Code is configured (hooks, skills, agents, settings, permissions, guardrail): the source lives in nxcore, not in ~/.claude/. If the current git repository is nxcore itself, search it directly (e.g. src/common/dev/claude.nix, src/common/dev/agents.nix). Otherwise look for nxcore at ~/.config/nx/nxcore. If that path does not exist on this machine, tell the user the change cannot be made here."
              "For Claude Code configuration: the source of truth is the nix files in nxcore. Never read or write ~/.claude/settings.json, ~/.claude/CLAUDE.md, ~/.claude/agents/, ~/.claude/skills/, or any other file under ~/.claude/ - those are generated build outputs. Reading them is wrong, and writing to them directly is wrong. All configuration changes must go through the nxcore nix source and a rebuild."
            ]
            [
              "Use the AskUserQuestion tool when:"
              "The user needs to pick between 2-4 distinct implementation approaches"
              "A decision has clear trade-offs that benefit from side-by-side comparison"
              "You would otherwise ask a free-form question the user would answer with a one-word reply"
              "After completing a review with findings: use AskUserQuestion to present each finding to the user one at a time, asking how they want it resolved. Work through all findings sequentially before making any changes."
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
          ++ lib.optional (!delegateEnabled) "Keep sub-agents to a minimum."
          ++ [
            "$NX_AGENTS_PLANS_DIR is always set by the claude wrapper to the plans directory for the current repo; use it directly without any slug computation."
            "For one-off scripts and ephemeral working files you will discard within the same session, use the session scratchpad path the harness injects at the top of the system prompt (the /tmp/claude-<uid>/... path) instead of $NX_AGENTS_PLANS_DIR/tmp. The session scratchpad (/tmp/claude-<uid>/...) is NOT the plans directory. They are completely separate. Never use the session scratchpad path as the plans directory or create archive/tmp subdirectories inside it."
            "rm -rf is blocked; use individual rm per file and rmdir for empty directories."
            "Never write file content via shell heredocs (e.g. cat >> file <<'EOF' ... EOF) or via shell output redirection (`>` or `>>`). These are hard rules with no exceptions: always use the Write or Edit tool for file writes."
          ]
          ++
            lib.optional (!delegateEnabled || reviewModel == null)
              "For code review and diff scanning tasks, use the injected review skills (review-pre-push-head, review-merge-request-head, etc.) instead of the built-in /code-review or /simplify slash commands.";
        }
        // lib.optionalAttrs delegateEnabled {
          "95 - Subagent Workflow" = [
            "All implementation, review, search, and web search work must be executed in subagents, not inline in the main session."
            "Always pass model: ${resolvedAgentModel} to the Agent tool when spawning subagents."
            "Always pass subagent_type: ${defaultAgentType} to the Agent tool unless spawning a named custom agent type."
            "Keep no more than ${builtins.toString maxAgents} subagents running concurrently."
            "When a subagent sends you a message: if it is a progress update, do NOT reply (replying resumes the subagent and causes a redundant extra turn); if it is a blocking question, reply immediately via SendMessage (at minimum 'Continue') so the subagent is not deadlocked. Never leave a waiting subagent without a reply."
          ]
          ++ lib.optional (webSearchModel != null) (
            lib.concatStringsSep "\n" [
              "Never call WebSearch or WebFetch directly in the main session. Always delegate web searches and fetches to a 'web' subagent (subagent_type: web). That agent is restricted to WebSearch and WebFetch only and cannot read files, edit files, or run commands."
              "To use it: Agent({ subagent_type: \"web\", prompt: \"search/fetch instructions\" })."
            ]
          )
          ++ lib.optional (reviewModel != null) (
            lib.concatStringsSep "\n" [
              "For code reviews and diff analysis, delegate to the 'review' subagent (subagent_type: review). The review agent will use the injected review skills internally."
              "To use it: Agent({ subagent_type: \"review\", prompt: \"review instructions\" })."
              "When a single review subagent finishes, repeat its ENTIRE summary verbatim as plain text in the chat, including every section it produced (Changes, Bugs/Inconsistencies, Security Issues, Privacy Leaks, Commits, verdict), before doing anything else. Never omit a section the subagent produced, even if it contains only a single item."
              "When the user requests multiple review agents, launch all simultaneously (up to the configured concurrency cap), then wait until ALL have finished before posting anything. Once all are done: verify each conflicting claim in the main session by reading the relevant source (a claim found by only one agent, or where agents directly contradict each other). Then produce ONE combined summary using the same section order and layout as a single review (Changes, Bugs/Inconsistencies grouped by severity, Security Issues, Privacy Leaks, Commits, verdict). Merge agreed findings as-is; include resolved conflicts with a one-sentence note on what you verified. Omit any finding section entirely if no agent reported anything for it. Never post individual per-agent summaries."
              "Never call ReportFindings in the main session after a delegated review: the card is invisible to the user and loses context."
            ]
          );
        };
        baseSkills = lib.optionalAttrs (!builtinCodeReviewEnabled) {
          code-review = "The built-in /code-review is disabled. Use the injected review skills instead (review-merge-request-head, review-pre-push-head, etc.).";
          simplify = "The built-in /simplify is disabled. Apply simplifications directly as code changes instead.";
        };
        baseAgents =
          lib.optionalAttrs (delegateEnabled && webSearchModel != null) {
            web = {
              description = "Web search and fetch agent. Retrieves web content only; no file, edit, or command access.";
              model = webSearchModel;
              effort = webSearchEffortLevel;
              tools = [
                "WebSearch"
                "WebFetch"
              ];
              text = "Only perform WebSearch and WebFetch operations. Return retrieved content to the main agent. Do not read files, edit files, run commands, or take any other actions.";
            };
          }
          // lib.optionalAttrs (delegateEnabled && reviewModel != null) {
            review = {
              description = "Code review agent. Performs thorough code reviews, security scans, and diff analysis.";
              model = reviewModel;
              effort = reviewEffortLevel;
              tools = [
                "Read"
                "Bash"
                "WebFetch"
                "WebSearch"
                "Skill"
                "ReportFindings"
              ];
              text = "Perform code reviews using the injected review skills (review-merge-request-head, review-pre-push-head, etc.). Report all findings clearly. Do not apply fixes unless explicitly instructed.";
            };
          }
          //
            lib.optionalAttrs
              (
                delegateEnabled
                && subagentEffortLevel != null
                && defaultAgentType != "web"
                && defaultAgentType != "review"
              )
              {
                ${defaultAgentType} = {
                  description = "General-purpose agent for implementation, review, search, and multi-step tasks.";
                  model = resolvedAgentModel;
                  effort = subagentEffortLevel;
                  tools = [ ];
                  text = "Complete the delegated task using all available tools. Work autonomously toward a conclusion.";
                };
              };

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
                  dirs[:] = sorted(d for d in dirs if depth == 0 or not d.startswith("."))
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

        baseAllowedEnvVars = [
          "PWD"
        ];

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
          "discourse.nixos.org"
          "mynixos.com"
          "wiki.archlinux.org"
          "hackage.haskell.org"
          "haskell.org"
          "docs.anthropic.com"
          "code.claude.com"
          "platform.claude.com"
          "claude.com"
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

        agentDenyBlock = lib.optionalString (!delegateEnabled) ''
          if tool_name == "Agent":
              deny("Subagents are disabled. Do this work yourself inline in the current session instead of delegating it.")
        '';

        generalPurposeDenyBlock =
          lib.optionalString (delegateEnabled && defaultAgentType != "general-purpose")
            ''
              if tool_name == "Agent" and tool_input(data).get("subagent_type") == "general-purpose":
                  deny("Use subagent_type '${defaultAgentType}' instead of 'general-purpose'; direct general-purpose calls bypass the configured effort level")
            '';

        missingSubagentTypeDenyBlock = lib.optionalString delegateEnabled ''
          if tool_name == "Agent" and not (tool_input(data).get("subagent_type") or "").strip():
              deny("You must pass an explicit subagent_type; choose a concrete agent (e.g. '${defaultAgentType}'). Omitting it falls back to the harness default and bypasses the configured effort level")
        '';

        codeReviewDenyBlock = lib.optionalString (!builtinCodeReviewEnabled) ''
          if tool_name == "Skill" and tool_input(data).get("skill") in ("code-review", "simplify"):
              deny("The built-in /code-review and /simplify commands are disabled. Use the injected review skills (review-merge-request-head, review-pre-push-head, etc.) instead.")
        '';

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
          CLAUDE_TMP = os.path.realpath(os.path.join("/tmp", "claude-" + str(os.getuid())))
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
          BASE_ALLOWED_ENV_VARS = ${builtins.toJSON baseAllowedEnvVars}
          EXTRA_ALLOWED_ENV_VARS = ${builtins.toJSON config.nx.common.dev.claude.guardrailAllowedEnvVars}
          FORBIDDEN_COMMANDS = ${builtins.toJSON forbiddenCommandWords}

          GREP_FAMILY = ("grep", "egrep", "fgrep")
          READONLY_FILTERS = GREP_FAMILY + (
              "rg", "tree", "sort", "head", "tail", "wc", "cut", "cat",
              "nl", "tac", "rev", "uniq", "comm", "column", "fmt", "fold",
              "ls", "tr", "jq", "yq", "date", "basename", "dirname", "printf", "diff",
              "test", "which",
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
                  lex.wordchars += '-./=~%@+:,*?'
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

          def _strip_safe_redirects(tokens):
              FD = ('1', '2')
              COMBINED_FD_REDIRECTS = frozenset(['>&1', '>&2', '1>&1', '1>&2', '2>&1', '2>&2'])
              result, i, n = [], 0, len(tokens)
              while i < n:
                  tok = tokens[i]
                  if tok in COMBINED_FD_REDIRECTS:
                      i += 1
                      continue
                  if tok == '>' and i + 1 < n and tokens[i + 1] == '/dev/null':
                      i += 2
                      continue
                  if ((tok.isdigit() or tok == '&') and i + 2 < n
                          and tokens[i + 1] == '>' and tokens[i + 2] == '/dev/null'):
                      i += 3
                      continue
                  if (tok == '>' and i + 2 < n
                          and tokens[i + 1] == '&' and tokens[i + 2] in FD):
                      i += 3
                      continue
                  if (tok in FD and i + 3 < n
                          and tokens[i + 1] == '>' and tokens[i + 2] == '&' and tokens[i + 3] in FD):
                      i += 4
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

          def is_readonly_listing(tokens, _depth=0):
              if tokens is None:
                  return "command could not be parsed"
              if _depth > 3:
                  ask("dev run --shell nesting too deep to analyse safely; manual review required")

              def _expand_allowed_vars(toks):
                  _ALLOWED = {"NX_AGENTS_PLANS_DIR": NX_AGENTS_PLANS_DIR}
                  for _var in BASE_ALLOWED_ENV_VARS + EXTRA_ALLOWED_ENV_VARS:
                      _val = cwd if _var == "PWD" else os.environ.get(_var)
                      if _val:
                          _ALLOWED[_var] = _val
                  result, i = [], 0
                  while i < len(toks):
                      tok = toks[i]
                      if tok == '$' and i + 1 < len(toks):
                          nxt = toks[i + 1]
                          for var, val in _ALLOWED.items():
                              if nxt == var:
                                  result.append(val)
                                  i += 2
                                  break
                              if nxt.startswith(var + '/'):
                                  result.append(val + nxt[len(var):])
                                  i += 2
                                  break
                          else:
                              result.append(tok)
                              i += 1
                      else:
                          result.append(tok)
                          i += 1
                  return result

              tokens = _expand_allowed_vars(tokens)
              tokens = _strip_safe_redirects(tokens)
              if re.search(r'[A-Za-z_][A-Za-z_0-9]*=[^\s;|&]+\s*[;&|].*\$[A-Za-z_{]', cmd):
                  deny("inline shell variable assignment followed by variable use is blocked; write literal values directly instead")
              if '$' in tokens:
                  ask("command contains an unexpanded shell variable; write literal values directly instead")

              def _in_allowed_root(tok):
                  part = tok.split("=", 1)[-1] if "=" in tok else tok
                  normalized = os.path.normpath(os.path.expanduser(part))
                  resolved = os.path.realpath(normalized)
                  if under(resolved, CLAUDE_TMP):
                      return True
                  if any(under(resolved, d) or under(normalized, d) for d in EXTRA_DIR_DENY):
                      deny("access to disallowed directory in shell command: " + resolved)
                  if any(under(resolved, s) or under(normalized, s) for s in SECRET_DIRS):
                      deny("access to secret directory in shell command: " + resolved)
                  if SECRET_FILE.search(resolved):
                      deny("access to secret material in shell command: " + resolved)
                  if any(under(normalized, r) for r in NX_INPUT_ROOTS):
                      return True
                  if under(resolved, NX_AGENTS_PLANS_DIR):
                      return True
                  if not cwd_root:
                      return False
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
                  if lead_cmd in ('true', 'false', 'echo', 'pwd'):
                      pass
                  elif lead_cmd == 'git':
                      if not re.match(r"^git(\s+(--no-pager|-C\s+\S+))*\s+(ls-files|log|status|check-ignore|diff|show|rev-parse)\b", lead):
                          return "git subcommand not in allowlist"
                      _lead_stripped = re.sub(r'\s+-c\s+diff\.external=(?=\s|$)', ' ', lead)
                      if re.search(r"(^|\s)(-c|--config|--exec-path|--git-dir|--work-tree|--namespace|--bare|--output)(=|\s|$)", _lead_stripped):
                          return "git command with unsafe flags"
                      for _gi, _gtok in enumerate(lead_tokens):
                          if _gtok == '-C' and _gi + 1 < len(lead_tokens):
                              _cpath = os.path.realpath(os.path.expanduser(lead_tokens[_gi + 1]))
                              if under(_cpath, os.path.realpath(NXCONFIG)) or _cpath == os.path.realpath(NXCONFIG):
                                  return "git -C pointing at nxconfig is blocked"
                              if any(under(_cpath, d) or _cpath == d for d in EXTRA_DIR_DENY):
                                  return "git -C pointing at disallowed directory: " + lead_tokens[_gi + 1]
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
                  elif lead_cmd == 'time':
                      if len(lead_tokens) >= 2:
                          return _check_part(part[1:])
                      return "bare time builtin"
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
                          if not under(resolved, cwd) and not under(resolved, NX_AGENTS_PLANS_DIR) and not under(resolved, CLAUDE_TMP):
                              return lead_cmd + " outside current directory: " + tok
                  elif lead_cmd == 'systemctl':
                      if not re.match(r"^systemctl(\s+(-[a-zA-Z]+|--[a-zA-Z0-9=-]+))*\s+(status|cat|show|is-active|is-enabled|is-failed|get-default|list-units|list-timers|list-sockets|list-jobs|list-unit-files)\b", lead):
                          return "systemctl subcommand not in allowlist"
                  elif lead_cmd == 'date':
                      if re.search(r"(^|\s)(-[a-zA-Z]*s|--(set)(=|\s|$))", lead):
                          return "date with clock-setting flag (-s/--set) is blocked"
                  elif lead_cmd == 'journalctl':
                      if re.search(r"(^|\s)(--vacuum-(size|time|files)|--rotate|--flush|--sync|--dmesg)\b", lead):
                          return "journalctl with mutating flag"
                      if re.search(r"(^|\s)-(?!-)[a-zA-Z]*k", lead):
                          return "journalctl with kernel flag"
                  elif lead_cmd == 'dev':
                      sub = lead_tokens[1:2]
                      if not sub:
                          return "bare dev command"
                      if sub[0] != 'run':
                          return "dev subcommand not in allowlist: " + sub[0]
                      run_args = lead_tokens[2:]
                      if not run_args:
                          return "dev run with no command"
                      if run_args[0] == '--shell':
                          if len(run_args) != 2:
                              return "dev run --shell expects exactly one argument"
                          inner_cmd = preprocess_cmd(run_args[1])
                          inner_tokens = _tokenize(inner_cmd)
                          return is_readonly_listing(inner_tokens, _depth + 1)
                      else:
                          return _check_part(run_args)
                  else:
                      return "command not auto-allowed, review required: " + lead_cmd
                  for stage in pipe_stages[1:]:
                      if not stage:
                          return "empty pipe segment"
                      tool = stage[0]
                      if tool == "xargs":
                          XARGS_BLOCKED = re.compile(
                              r'^(-a|--arg-file|-[iI]|--replace|-o|--open-tty|-p|--interactive|--process-slot-var)(=|$)'
                          )
                          XARGS_TAKES_ARG = frozenset(['-d', '-E', '-e', '-I', '-L', '-l', '-n', '-P', '-s'])
                          xargs_cmd = None
                          xargs_args = stage[1:]
                          xi = 0
                          while xi < len(xargs_args):
                              tok = xargs_args[xi]
                              if XARGS_BLOCKED.match(tok):
                                  return "xargs with unsafe flag: " + tok
                              if tok.startswith('-') and not tok.startswith('--') and tok[1:2] in XARGS_TAKES_ARG:
                                  xi += 2
                                  continue
                              if tok.startswith('--') and '=' not in tok:
                                  xi += 1
                                  continue
                              if tok.startswith('-'):
                                  xi += 1
                                  continue
                              xargs_cmd = tok
                              break
                          if xargs_cmd is None:
                              return "xargs with no command"
                          if xargs_cmd not in READONLY_FILTERS:
                              return "xargs command not in read-only set: " + xargs_cmd
                          xargs_sub = xargs_args[xi + 1:]
                          for tok in xargs_sub:
                              if tok in ('{', '}'):
                                  return "shell metacharacter in command"
                              if '..' in tok:
                                  return "path traversal (..) in command"
                              if re.match(r"^[/~]", tok) or re.search(r"=[/~]", tok):
                                  if not _in_allowed_root(tok):
                                      return "absolute path not under a recognised git root: " + tok
                          if xargs_cmd not in GREP_FAMILY:
                              for tok in xargs_sub:
                                  if re.match(r"^(-o|-O|--output|--output-file|--out-file)(=|$)", tok):
                                      return "output redirection flag in read-only command"
                          if xargs_cmd == 'rg':
                              for tok in xargs_sub:
                                  if re.match(r"^(--pre|--pre-glob|--hostname-bin)(=|$)", tok):
                                      return "rg with exec flag"
                          if xargs_cmd == 'yq':
                              for tok in xargs_sub:
                                  if re.match(r"^(-i|--in-place)(=|$)", tok):
                                      return "yq with in-place flag"
                          continue
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
          cwd_root = run([GIT, "-C", cwd, "rev-parse", "--show-toplevel"], cwd)
          NX_AGENTS_PLANS_DIR = os.environ.get("NX_AGENTS_PLANS_DIR") or os.path.join(HOME, ".local", "share", "nx", "agents", "plans", cwd.replace("/", "-").replace(".", "-"))
          path = tool_path(data)
          cmd = tool_input(data).get("command") or ""
          url = tool_input(data).get("url") or ""
          tool_name = data.get("tool_name") or ""

          BAKED_WEB_DOMAINS = set(${builtins.toJSON bakedWebDomains})
          ALLOWED_WEB_PATTERNS = ${builtins.toJSON config.nx.common.dev.claude.allowedWebFetchDomains}

          ${forkDenyBlock}
          ${nestedDenyBlock}
          ${agentDenyBlock}
          ${generalPurposeDenyBlock}
          ${missingSubagentTypeDenyBlock}
          ${codeReviewDenyBlock}
          if tool_name == "Agent" and tool_input(data).get("subagent_type") == "claude-code-guide":
              deny("The claude-code-guide agent is disabled. Search docs.anthropic.com or code.claude.com for the information you need.")
          if tool_name == "Skill" and tool_input(data).get("skill") == "claude-api":
              deny("The claude-api skill is disabled. Search docs.anthropic.com or code.claude.com for the information you need.")
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

          AGENT_INSTRUCTION_FILES = frozenset(("AGENTS.md", "CLAUDE.md"))
          if path:
              target = resolve(cwd, path)
              if (tool_name in ("Read", "Write", "Edit")
                      and os.path.basename(target) in AGENT_INSTRUCTION_FILES
                      and cwd_root
                      and os.path.realpath(target) == os.path.join(cwd_root, os.path.basename(target))):
                  allow("agent instruction file in current repo root: " + target)
              if under(target, NXCONFIG):
                  real_target = os.path.realpath(target)
                  if nxconfig_allowed(target) and not any(under(real_target, s) for s in SECRET_DIRS) and not SECRET_FILE.search(real_target):
                      allow("nxconfig markdown or flake file: " + target)
                  else:
                      deny("access to nxconfig is off-limits: " + target)
              if tool_name == "Read" and any(under(target, r) for r in NX_INPUT_ROOTS):
                  allow("read from nx inputs")
              if under(os.path.realpath(target), CLAUDE_TMP):
                  allow("access to claude temp directory")
              if any(under(target, d) for d in EXTRA_DIR_DENY):
                  if tool_name == "Read" and under(target, "/nix/store"):
                      ask("reading from nix store: " + target)
                  deny("access to disallowed directory: " + target)
              if any(under(target, secret) for secret in SECRET_DIRS):
                  deny("access to secret material is blocked: " + target)
              if SECRET_FILE.search(target):
                  deny("access to secret material is blocked: " + target)
              if tool_name in ("Read", "Write", "Edit") and under(target, NX_AGENTS_PLANS_DIR):
                  allow("access to the agents plans dir")
              for pattern in EXTRA_PATH_DENY:
                  if re.search(pattern, target):
                      deny("path denied by guardrailDisallowedPaths: " + target)
              if tool_name == "Read":
                  real_target = os.path.realpath(target)
                  if cwd_root and under(real_target, os.path.realpath(cwd_root)):
                      allow("read within project")
                  try:
                      parent = real_target if os.path.isdir(real_target) else os.path.dirname(real_target)
                      r = subprocess.run([GIT, "-C", parent, "rev-parse", "--show-toplevel"],
                                         capture_output=True, text=True, timeout=3)
                      raw = r.stdout.strip()
                      if raw and cwd_root:
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
              if re.search(r"\brg\b[^|&;\n]*\s(-(?!-)\w*r\w*|--replace\b)", cmd):
                  deny("rg -r/--replace rewrites match output; remove the flag (rg is already recursive by default)")
              if re.search(r'(?<![<])<<(?!<)', cmd):
                  if re.search(r'(?<![<])>(?!&)', cmd):
                      deny("heredoc file writing is blocked; use the Write or Edit tool for file writes")
                  else:
                      ask("command contains a heredoc")
              for _seg in re.split(r'&&|\|\||;', cmd):
                  if re.search(r"\bgit\b.*\bpush\b", _seg) and re.search(r"(--force(\W|$)|\s-f(\s|$))", _seg) and not re.search(r"--force-with-lease", _seg):
                      deny("git push --force is blocked")
                  if re.search(r"\bgit\b.*\b(commit|push|pull|fetch)\b", _seg):
                      deny("git commit, push, pull and fetch are blocked")
              if re.search(r"(^|[;&|()\s])(ssh|scp|rsync)\b(?!-)", cmd):
                  deny("ssh, scp and rsync are blocked")
              if re.search(r"\bdd\s.*of=/dev/", cmd):
                  deny("writing with dd to a block device is blocked")
              if re.search(r'\bpython3?\b[^|&;]*\s-c\b', cmd):
                  deny("python inline scripts are blocked; use jq/yq/rg and dedicated tools instead")
              if re.search(r"(curl|wget)[^|]*\|[^|]*(sh|bash|python3?|perl|ruby|node)", cmd):
                  deny("piping a download into a shell or interpreter is blocked")
              if re.search(r"/\.config/nx/nxconfig|\.\./nxconfig", cmd):
                  _cp_to_nxconfig_md = bool(re.fullmatch(
                      r'command\s+cp\s+(-f\s+)*[^/\s;&|`$<>(){}\n]+\.md\s+[^\s;&|`$<>(){}\n]*(\.config/nx/nxconfig|\.\./nxconfig)/[^/\s;&|`$<>(){}\n]+\.md',
                      cmd.strip(),
                      re.ASCII
                  ))
                  if _cp_to_nxconfig_md:
                      ask("cp of local .md file into nxconfig: " + cmd)
                  else:
                      deny("referencing nxconfig from a shell command is blocked")
              META = frozenset(['<', '>', '`', '(', ')', '$', '{', '}'])
              if tokens and not any(t in META for t in tokens):
                  for _tok in tokens[1:]:
                      if not _tok.startswith('-') and ('/' in _tok or _tok.startswith('~') or _tok.startswith('.') or '*' in _tok or '?' in _tok):
                          if ('*' in _tok or '?' in _tok) and SECRET_FILE.search(_tok):
                              deny("access to secret material in shell command: " + _tok)
                          _p = os.path.normpath(os.path.expanduser(_tok))
                          _r = os.path.realpath(_p)
                          if any(under(_r, d) or under(_p, d) for d in EXTRA_DIR_DENY):
                              if not under(_r, CLAUDE_TMP):
                                  deny("access to disallowed directory in shell command: " + _r)
                          if any(under(_r, s) or under(_p, s) for s in SECRET_DIRS):
                              deny("access to secret directory in shell command: " + _r)
                          if SECRET_FILE.search(_r) and not under(_r, CLAUDE_TMP):
                              deny("access to secret material in shell command: " + _r)
              mutation_parts = _split_on(tokens, OPERATORS | {'|', '&'}) if tokens else []
              if len(mutation_parts) == 1:
                  seg = mutation_parts[0]
                  while seg and seg[0] == 'command':
                      seg = seg[1:]
                  META = frozenset(['<', '>', '`', '(', ')', '$', '{', '}'])
                  if seg and seg[0] in ('mv', 'rm', 'touch'):
                      _eseg, _i = [], 0
                      while _i < len(seg):
                          if seg[_i] == '$' and _i + 1 < len(seg) and (
                              seg[_i + 1] == 'NX_AGENTS_PLANS_DIR'
                              or seg[_i + 1].startswith('NX_AGENTS_PLANS_DIR/')
                          ):
                              _eseg.append(NX_AGENTS_PLANS_DIR + seg[_i + 1][len('NX_AGENTS_PLANS_DIR'):])
                              _i += 2
                          elif seg[_i] == '$' and _i + 1 < len(seg) and (
                              seg[_i + 1] == 'CLAUDE_TMP'
                              or seg[_i + 1].startswith('CLAUDE_TMP/')
                          ):
                              _eseg.append(CLAUDE_TMP + seg[_i + 1][len('CLAUDE_TMP'):])
                              _i += 2
                          else:
                              _eseg.append(seg[_i])
                              _i += 1
                      if not any(t in META for t in _eseg):
                          path_toks = [t for t in _eseg[1:] if not t.startswith('-')]
                          if path_toks and all(
                              under(resolve(cwd, os.path.expanduser(p)), NX_AGENTS_PLANS_DIR)
                              or under(resolve(cwd, os.path.expanduser(p)), CLAUDE_TMP)
                              for p in path_toks
                          ):
                              allow("mv/rm/touch confined to the agents plans dir or session scratchpad")
              if re.search(r'\$\(|`', cmd):
                  ask("command contains a subshell substitution")
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

          if event == "SessionStart":
              try:
                  _cutoff = datetime.now().timestamp() - 7 * 86400
                  _sd = state_dir()
                  for _fname in os.listdir(_sd):
                      _fpath = os.path.join(_sd, _fname)
                      if os.path.isfile(_fpath) and os.path.getmtime(_fpath) < _cutoff:
                          os.remove(_fpath)
              except Exception:
                  pass

          sections = ["=== Session Context ===\nDate: " + datetime.now().strftime("%Y-%m-%d %H:%M")]

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
                  sections.append("Project directories (COMPLETE list of every dir containing files, dotfiles excluded, root dotdirs included):\n" + project_tree(cwd))
                  sections.append("Files in the top two levels only (repo root and one level deep; this is NOT the full file list, deeper files are omitted, use the directory list above to locate them):\n" + shallow_files(cwd))

          last = pointer_path(data.get("session_id"))
          if event == "PostCompact" and os.path.isfile(last):
              with open(last) as handle:
                  sections.append("=== Pre-Compact Snapshot ===\n" + handle.read().strip() + "\n(Do not read this file in full with Read or cat - it may be very large. Use head, tail, or jq with line limits if inspection is needed.)")
          if event == "PostCompact":
              _style_text = ${builtins.toJSON styleText}
              if _style_text:
                  sections.append("=== Style Reminder ===\n\n" + _style_text + "\n\nApply these rules immediately to all your responses, without exception.")
          ${lib.optionalString (claudeMdReminderInterval != null) ''
            if event == "PostCompact":
                _claude_md_path = os.path.join(HOME, ".claude", "CLAUDE.md")
                try:
                    with open(_claude_md_path) as fh:
                        _claude_md = fh.read().strip()
                    if _claude_md:
                        sections.append("=== Global CLAUDE.md ===\n\n" + _claude_md)
                except Exception:
                    pass
          ''}
          ${lib.optionalString (recentMessagesOnCompact != null) ''
            RECENT_MSGS_LIMIT = ${builtins.toString recentMessagesOnCompact}
            if event == "PostCompact" and os.path.isfile(last):
                _snap_path = ""
                try:
                    with open(last) as fh:
                        _snap_path = fh.read().strip()
                except Exception:
                    pass
                if _snap_path and os.path.isfile(_snap_path):
                    def _extract_text(content):
                        if isinstance(content, str):
                            return content.strip()
                        parts = []
                        stubs = []
                        for block in (content or []):
                            if isinstance(block, dict):
                                if block.get("type") == "text":
                                    t = (block.get("text") or "").strip()
                                    if t:
                                        parts.append(t)
                                elif block.get("type") == "tool_use":
                                    stubs.append("[tool call: " + (block.get("name") or "unknown") + "]")
                        return "\n".join(parts) if parts else "\n".join(stubs)
                    _raw = []
                    try:
                        with open(_snap_path) as fh:
                            for _line in fh:
                                try:
                                    _obj = json.loads(_line)
                                    _msg = _obj.get("message")
                                    if _msg and _msg.get("role") in ("user", "assistant"):
                                        _text = _extract_text(_msg.get("content") or [])
                                        if (
                                            _text
                                            and not _text.startswith("[Request interrupted")
                                            and not _text.startswith("<task-notification")
                                            and not (_msg["role"] == "user" and _text.startswith("/"))
                                            and not _text.startswith("[Your previous response had no visible output")
                                        ):
                                            _raw.append((_msg["role"], _text))
                                except Exception:
                                    continue
                    except Exception:
                        pass
                    _group_starts = []
                    for _gi, (_gr, _gt) in enumerate(_raw):
                        if _gr == "user" and (_gi == 0 or _raw[_gi - 1][0] != "user"):
                            _group_starts.append(_gi)
                    _selected = []
                    _total_chars = 0
                    for _gk in range(len(_group_starts) - 1, -1, -1):
                        _gs = _group_starts[_gk]
                        _ge = _group_starts[_gk + 1] if _gk + 1 < len(_group_starts) else len(_raw)
                        _group = _raw[_gs:_ge]
                        _gc = sum(len(_gt) for _, _gt in _group)
                        if _total_chars + _gc > RECENT_MSGS_LIMIT and _selected:
                            break
                        _selected.insert(0, _group)
                        _total_chars += _gc
                    if _selected:
                        _merged = []
                        for _group in _selected:
                            for _gr, _gt in _group:
                                if _merged and _merged[-1][0] == _gr:
                                    _sep = "\n" if _gt.startswith("[") and _merged[-1][1].split("\n")[-1].startswith("[") else "\n\n"
                                    _merged[-1] = (_gr, _merged[-1][1] + _sep + _gt)
                                else:
                                    _merged.append((_gr, _gt))
                        _lines = []
                        for _gr, _gt in _merged:
                            _label = "**User**" if _gr == "user" else "**Assistant**"
                            _lines.append(_label + "\n\n" + _gt)
                        sections.append("=== Recent Messages ===\n\n" + "\n\n---\n\n".join(_lines))
          ''}
          ${lib.optionalString (styleReminderInterval != null || claudeMdReminderInterval != null) ''
            if event == "PostCompact":
                _sid = data.get("session_id") or "default"
                _counter_file = os.path.join(state_dir(), "style-turn-" + safe_id(_sid))
                try:
                    with open(_counter_file, "w") as fh:
                        fh.write("0\n")
                except Exception:
                    pass
          ''}
          if event == "PostCompact":
              _plans_dir = os.environ.get("NX_AGENTS_PLANS_DIR", "")
              if _plans_dir and os.path.isdir(_plans_dir):
                  _active_plans = [
                      f for f in os.listdir(_plans_dir)
                      if f.endswith(".md") and os.path.isfile(os.path.join(_plans_dir, f))
                  ]
                  if _active_plans:
                      _plan_list = "\n".join("- " + p for p in sorted(_active_plans))
                      sections.append(
                          "=== Active Plans ===\n\n"
                          "The following plan files exist in " + _plans_dir + ":\n\n" + _plan_list + "\n\n"
                          "Only read a plan file if its name appears in the session context above (recent messages or pre-compact snapshot). "
                          "Do not read plan files speculatively or because they exist. "
                          "If a plan you were working on is named above, read it on your next turn before continuing."
                      )

          context("\n\n".join(sections), event)
        '';

        precompactBody = ''
          data = load()
          snapshot(data.get("transcript_path"), data.get("session_id"))
        '';

        userPromptReminderBody =
          let
            hasStyle = styleReminderInterval != null && styleText != "";
            hasClaude = claudeMdReminderInterval != null;
          in
          ''
            ${lib.optionalString hasStyle "STYLE_TEXT = ${builtins.toJSON styleText}"}
            ${lib.optionalString (
              styleReminderInterval != null
            ) "STYLE_INTERVAL = ${builtins.toString styleReminderInterval}"}
            ${lib.optionalString hasClaude "CLAUDE_MD_INTERVAL = ${builtins.toString claudeMdReminderInterval}"}
            CLAUDE_MD_PATH = os.path.join(HOME, ".claude", "CLAUDE.md")

            data = load()
            session_id = data.get("session_id") or "default"
            counter_file = os.path.join(state_dir(), "style-turn-" + safe_id(session_id))

            try:
                with open(counter_file) as fh:
                    count = int(fh.read().strip())
            except Exception:
                count = 0

            count += 1
            with open(counter_file, "w") as fh:
                fh.write(str(count) + "\n")

            sections = []

            ctx_file = os.path.join(state_dir(), "ctx-" + safe_id(session_id) + ".json")
            try:
                with open(ctx_file) as fh:
                    ctx = json.load(fh)
                current = ctx.get("current_tokens", 0)
                compact_threshold = ctx.get("compact_threshold_tokens", 0)
                compact_pct = ctx.get("compact_threshold_pct", 100)
                ctx_pct = ctx.get("context_pct", 0)
                max_tokens = ctx.get("max_tokens", 0)
                if current > 0:
                    token_line = "Context: " + str(current) + " tokens used"
                    if compact_threshold > 0:
                        remaining = compact_threshold - current
                        token_line += " (" + str(ctx_pct) + "% toward compaction at " + str(compact_threshold) + " / " + str(compact_pct) + "% of " + str(max_tokens) + ")"
                        token_line += ", " + str(remaining) + " tokens remaining before auto-compact"
                    sections.append(token_line)
                    if ctx_pct >= 75:
                        sections.append(
                            "Context notice: " + str(ctx_pct) + "% of the compaction threshold is used. "
                            "Keep all active plans, task lists, and notes current as you work: "
                            "reflect any new findings, decisions, or progress in them as each change happens, "
                            "so nothing is lost if compaction occurs mid-session."
                        )
            except Exception:
                pass

            ${lib.optionalString hasStyle ''
              if count % STYLE_INTERVAL == 0:
                  sections.append("Style reminder (periodic re-injection every " + str(STYLE_INTERVAL) + " turns):\n\n" + STYLE_TEXT + "\n\nApply these rules immediately to all your responses, without exception.")
            ''}
            ${lib.optionalString hasClaude ''
              if count % CLAUDE_MD_INTERVAL == 0:
                  try:
                      with open(CLAUDE_MD_PATH) as fh:
                          claude_md = fh.read().strip()
                      if claude_md:
                          sections.append("Global CLAUDE.md re-injection (periodic, every " + str(CLAUDE_MD_INTERVAL) + " turns):\n\n" + claude_md)
                  except Exception:
                      pass
            ''}

            if sections:
                sys.stdout.write("\n\n".join(sections) + "\n")
            sys.exit(0)
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
        userPromptReminderScript = mkPythonHook "nx-claude-prompt-reminder" userPromptReminderBody;

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
        }
        // lib.optionalAttrs (userPromptReminderScript != null) {
          UserPromptSubmit = {
            command = userPromptReminderScript;
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

        sharedInstructionsForClaude = sharedAgents.instructions // {
          "02 - Session Start" = (sharedAgents.instructions."02 - Session Start" or [ ]) ++ [
            [
              "After completing the mandatory session-start steps, check whether the current working directory is inside a git repo whose root contains AGENTS.md but no CLAUDE.md."
              "If so, read AGENTS.md immediately as the next action before responding."
              "No action needed if CLAUDE.md is present, if neither file exists, or if the working directory is not inside a git repo."
            ]
          ];
        };

        mergedContext = renderMerged [
          sharedInstructionsForClaude
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
        defaultSubagentType = config.nx.common.dev.claude.defaultSubagentType;
        validSubagentTypes = builtins.attrNames mergedAgents;

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
            wrapProgram $out/bin/claude \
              ${lib.concatStringsSep " " claudeWrapperArgs}
          '';
        };
        baseClaude = if claudeWrapperArgs != [ ] then claude-code-wrapped else pkgs.claude-code;
        claude-with-plans = pkgs.writeShellScriptBin "claude" ''
          if ! ${pkgs.git}/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            printf "\033[1;31m\033[1mError: claude must be run from inside a git repository.\033[0m\n" >&2
            exit 1
          fi
          if [ -z "''${NX_AGENTS_PLANS_DIR:-}" ]; then
            slug="''${PWD//[\/.]/-}"
            NX_AGENTS_PLANS_DIR="$HOME/.local/share/nx/agents/plans/$slug"
          fi
          mkdir -p "$NX_AGENTS_PLANS_DIR/archive"
          mkdir -p "$NX_AGENTS_PLANS_DIR/tmp"
          export NX_AGENTS_PLANS_DIR
          export CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1
          exec ${baseClaude}/bin/claude "$@"
        '';
        claude-package = claude-with-plans;

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
          session_id=""
          if command -v jq >/dev/null 2>&1; then
            {
              IFS= read -r model
              IFS= read -r dir
              IFS= read -r session_id
              IFS= read -r ctx_pct
              IFS= read -r five_h
              IFS= read -r five_h_reset
              IFS= read -r week
              IFS= read -r week_reset
              IFS= read -r exceeds
              IFS= read -r tokens
              IFS= read -r cost
              IFS= read -r model_window
            } <<< "$(printf '%s' "$input" | jq -r '
              (.model.display_name // "Claude"),
              (.workspace.current_dir // .cwd // ""),
              (.session_id // ""),
              (.context_window.used_percentage | if . then (. | floor | tostring) else "" end),
              (.rate_limits.five_hour.used_percentage | if . then (. | floor | tostring) else "" end),
              (.rate_limits.five_hour.resets_at | if . then tostring else "" end),
              (.rate_limits.seven_day.used_percentage | if . then (. | floor | tostring) else "" end),
              (.rate_limits.seven_day.resets_at | if . then tostring else "" end),
              (.exceeds_200k_tokens // false | tostring),
              (.context_window.total_input_tokens | if . then tostring else "" end),
              (.cost.total_cost_usd | if . then tostring else "" end),
              (if ((.context_window.used_percentage // 0) > 0) and ((.context_window.total_input_tokens // 0) > 0)
               then ((.context_window.total_input_tokens * 100 / .context_window.used_percentage / 1000 | ceil) * 1000 | tostring)
               else "" end)
            ')"
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
          if repo_root=$(git -C "$dir" --no-optional-locks rev-parse --show-toplevel 2>/dev/null); then
            branch=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null)
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

          if [ -n "$session_id" ] && [ -n "$tokens" ]; then
            _safe_sid=$(printf '%s' "$session_id" | tr -cs 'A-Za-z0-9_-' '_')
            _state_dir="''${XDG_RUNTIME_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}}/nx-claude"
            mkdir -p "$_state_dir"
            printf '{"current_tokens":%s,"max_tokens":%s,"compact_threshold_tokens":%s,"compact_threshold_pct":%s,"context_pct":%s}\n' \
              "''${tokens:-0}" \
              "''${model_window:-0}" \
              "''${threshold_tokens:-0}" \
              "''${COMPACT_PCT:-100}" \
              "''${ctx_pct:-0}" \
              > "$_state_dir/ctx-$_safe_sid.json"
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
        assertions = lib.optional delegateToSubagents {
          assertion = lib.elem defaultSubagentType validSubagentTypes;
          message = "nx.common.dev.claude.defaultSubagentType must be a name injected via nx.common.dev.claude.agents or nx.common.dev.agents.agents (got \"${defaultSubagentType}\"; available: ${builtins.concatStringsSep ", " validSubagentTypes})!";
        };

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
            permissions.defaultMode = if permissionMode == "manual" then "default" else permissionMode;
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
              toolsPart = lib.optionalString (
                value.tools != [ ]
              ) "\ntools: ${lib.concatStringsSep ", " value.tools}";
              modelLine = lib.optionalString (value.model != null) "\nmodel: ${value.model}";
              effortLine = lib.optionalString (value.effort != null) "\neffort: ${value.effort}";
            in
            ''
              ---
              name: ${builtins.toJSON name}
              description: ${builtins.toJSON desc}${toolsPart}${modelLine}${effortLine}
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
