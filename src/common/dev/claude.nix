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
  name = "claude";

  group = "dev";
  input = "common";

  unfree = [ "claude-code" ];

  options = {
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

    model = lib.mkOption {
      type = lib.types.str;
      default = "sonnet";
      description = "Default Claude Code model.";
    };

    effortLevel = lib.mkOption {
      type = lib.types.str;
      default = "high";
      description = "Default Claude Code effort level.";
    };

    notifyEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable agent push notifications.";
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
  };

  submodules = {
    common = {
      dev = [ "agents" ];
    };
  };

  module = {
    enabled =
      config:
      let
        baseInstructions = {
          "90 - Claude" = [
            "Use the conversation as initial context, then read only the files and local context required to complete the request."
            "Batch all changes into as few operations as possible."
            "Don't analyse too much on first feasibility questions to avoid wasting tokens."
            "Keep sub-agents to a minimum."
            [
              "Use the AskUserQuestion tool when:"
              "The user needs to pick between 2-4 distinct implementation approaches"
              "A decision has clear trade-offs that benefit from side-by-side comparison"
              "You would otherwise ask a free-form question the user would answer with a one-word reply"
              "You did a review and we need to make decisions for fixing individual issues one by one"
              "Even with many choices to present, still use this tool: split them across multiple questions rather than skipping it, since each question accepts at most 4 options and a single call accepts at most 4 questions"
            ]
            [
              "Remote / Mobile Sessions"
              "When the user says they are remote or mobile (or using a phone or tablet), show every change verbatim in the chat - as an inline diff or as the full updated content - before issuing the actual Edit/Write/Bash tool call. This lets the user review and approve the changes without needing to inspect the tool call details."
            ]
          ];
        };
        baseSkills = { };
        baseAgents = { };
      in
      {
        nx.common.dev.agents.enabledAgents = [ "claude" ];

        nx.common.dev.claude.instructions = lib.mkOrder 200 baseInstructions;

        nx.common.dev.claude.skills = lib.mkOrder 200 baseSkills;
        nx.common.dev.claude.agents = lib.mkOrder 200 baseAgents;

        nx.common.git.git.globalIgnores = [
          "CLAUDE.md"
          ".claude"
        ];
      };

    home =
      {
        config,
        instructions,
        skills,
        agents,
        autoCompact,
        model,
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
        ...
      }:
      let
        sharedAgents = config.nx.common.dev.agents;
        renderInstructions = self.common.dev.agents.exports.renderInstructions;

        tc = config.nx.preferences.theme.colors;
        ansi = color: helpers.hexToAnsiRgb color.html;

        mergedInstructions = helpers.deepMergeComplex {
          base = sharedAgents.instructions;
          override = instructions;
        };
        mergedContext = renderInstructions mergedInstructions;

        mergedSkills = sharedAgents.skills // skills;

        mergedAgents = sharedAgents.agents // agents;

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
        claude-code-wrapped = pkgs.symlinkJoin {
          name = "claude-code-wrapped";
          paths = [ pkgs.claude-code ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/claude \
              --prefix PATH : ${fake-ssh}/bin \
              --set GIT_CONFIG_COUNT 1 \
              --set GIT_CONFIG_KEY_0 "url.https://github.com/.insteadOf" \
              --set GIT_CONFIG_VALUE_0 "git@github.com:"
          '';
        };
        claude-package =
          if githubEnforceSSH && config.nx.linux.security.yubikey.enable then
            claude-code-wrapped
          else
            pkgs.claude-code;

        statusline-command = pkgs.writeShellScript "statusline-command" ''
          input=$(cat)

          ctx_pct=""
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

          ctx_fg="$VAL_FG"; ctx_bg="$BODY_BG"
          [ -n "$ctx_pct" ] && [ "$ctx_pct" -gt 75 ] && { ctx_fg="$INK"; ctx_bg="$ERR_BG"; }
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
          [ "$exceeds" = "true" ] && { tokens_fg="$INK"; tokens_bg="$ERR_BG"; }
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
            outputStyle = "default";
            inherit
              alwaysThinkingEnabled
              fileCheckpointingEnabled
              disableWorkflows
              enableArtifact
              ;
            inherit editorMode askUserQuestionTimeout;
            inherit spinnerTipsEnabled awaySummaryEnabled autoScrollEnabled;
            inherit remoteControlAtStartup;
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
        };

        home = {
          file = {
            ".config/doom/config/80-claude.el".text =
              if (self.isModuleEnabled "emacs.doom") then
                ''
                  (use-package claude-code-ide
                    :bind ("C-c '" . claude-code-ide-menu)
                    :config
                    (claude-code-ide-emacs-tools-setup)
                    (setq claude-code-ide-terminal-backend 'eat))
                ''
              else
                "";

            ".config/doom/packages/80-claude.el".text =
              if (self.isModuleEnabled "emacs.doom") then
                ''
                  (package! claude-code-ide
                    :recipe (:host github :repo "manzaltu/claude-code-ide.el" :files ("*.el")))
                ''
              else
                "";
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
