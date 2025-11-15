args@{
  lib,
  pkgs,
  pkgs-unstable,
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
  namespace = "home";

  unfree = [ "claude-code" ];

  settings = {
    additionalMCPServers = { };
  };

  configuration =
    context@{ config, options, ... }:
    {
      home = {
        packages = with pkgs-unstable; [
          claude-code
        ];

        file =
          let
            allMCPServers =
              self.settings.additionalMCPServers
              // lib.optionalAttrs (self.isModuleEnabled "nvim.mcp-server") {
                "mcp-neovim-server" = {
                  command = "mcp-neovim-server-wrapper";
                  args = [ ];
                  env = {
                    ALLOW_SHELL_COMMANDS = "false";
                  };
                };
              };

            mcpFiles = lib.mapAttrs' (name: config: {
              name = ".config/claude-mcp/${name}.json";
              value = {
                text = builtins.toJSON config;
              };
            }) allMCPServers;
          in
          {
            ".config/nvim-init/90-claude-code.lua" = lib.mkIf (self.isModuleEnabled "nvim.nixvim") {
              text = ''
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
              '';
            };

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

            ".local/bin/claude-configure-mcp-servers" = {
              executable = true;
              text = ''
                #!/usr/bin/env bash

                MCP_DIR="$HOME/.config/claude-mcp"

                if [[ ! -d "$MCP_DIR" ]]; then
                  echo "No MCP configuration directory found at $MCP_DIR"
                  exit 0
                fi

                echo "Managing MCP servers from $MCP_DIR..."

                for json_file in "$MCP_DIR"/*.json; do
                  [[ -f "$json_file" ]] || continue

                  server_name=$(basename "$json_file" .json)

                  if claude mcp get "$server_name" >/dev/null 2>&1; then
                    echo "→ Removing existing MCP server '$server_name'..."
                    claude mcp remove "$server_name"
                  fi

                  echo "→ Adding MCP server '$server_name'..."
                  if claude mcp add-json --scope user "$server_name" "$(cat "$json_file")"; then
                    echo "✓ Successfully configured '$server_name'"
                  else
                    echo "✗ Failed to configure '$server_name'"
                  fi
                done

                echo "MCP server configuration complete. Run 'claude mcp list' to verify."
              '';
            };
          }
          // mcpFiles;

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
      };

    };
}
