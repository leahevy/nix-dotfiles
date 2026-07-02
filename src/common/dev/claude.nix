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
      };

    home =
      {
        config,
        instructions,
        skills,
        agents,
        ...
      }:
      let
        sharedAgents = config.nx.common.dev.agents;
        renderInstructions = self.common.dev.agents.exports.renderInstructions;

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
      in
      {
        programs.claude-code = {
          enable = true;
          package = claude-package;
          enableMcpIntegration = true;
          context = mergedContext;
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
