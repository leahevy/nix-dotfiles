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
  name = "copilot";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    baseFiletypesToEnable = [
      "nix"
      "python"
      "rust"
      "go"
      "javascript"
      "typescript"
      "lua"
      "c"
      "cpp"
      "c_sharp"
      "haskell"
      "ruby"
      "scala"
      "swift"
      "r"
      "matlab"
      "objc"
      "solidity"
      "html"
      "css"
      "scss"
      "graphql"
      "json"
      "jsonc"
      "bash"
      "fish"
      "powershell"
      "vim"
      "dockerfile"
      "terraform"
      "cmake"
      "make"
      "asm"
      "nasm"
      "glsl"
      "sql"
      "proto"
      "groovy"
    ];
    additionalFiletypesToEnable = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs-unstable; [
        nodejs
      ];

      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          copilot-vim
        ];

        globals = {
          copilot_no_tab_map = true;
          copilot_assume_mapped = true;
          copilot_enabled = false;
        };

        keymaps = [
          {
            mode = "i";
            key = "<Tab>";
            action = "empty(copilot#GetDisplayedSuggestion()) ? '\\<Tab>' : copilot#Accept()";
            options = {
              desc = "Accept Copilot suggestion";
              silent = true;
              expr = true;
              replace_keycodes = false;
            };
          }
          {
            mode = "i";
            key = "<M-Tab>";
            action = "<cmd>lua vim.api.nvim_feedkeys('\t', 'n', false)<CR>";
            options = {
              desc = "Insert tab (fallback)";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>cq";
            action = ":lua local status = vim.fn.execute('Copilot status'); if string.match(status, 'Ready') then vim.notify('❌ Feature disabled', vim.log.levels.INFO, { title = 'Copilot' }); vim.cmd('Copilot disable') else vim.notify('✅ Feature enabled', vim.log.levels.INFO, { title = 'Copilot' }); vim.cmd('Copilot enable') end<CR>";
            options = {
              desc = "Toggle Copilot";
              silent = false;
            };
          }
        ];

        autoCmd = lib.mkIf (self.isModuleEnabled "nvim-modules.vimwiki") [
          {
            event = [ "BufEnter" ];
            pattern = [ "*.md" ];
            callback.__raw = ''
              function()
                if vim.bo.filetype == "vimwiki" then
                  vim.defer_fn(function()
                    vim.keymap.set('i', '<Tab>',
                      "empty(copilot#GetDisplayedSuggestion()) ? '\\<Tab>' : copilot#Accept()",
                      { buffer = 0, desc = "Accept Copilot suggestion", silent = true, expr = true, replace_keycodes = false }
                    )
                  end, 10)
                end
              end
            '';
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<Tab>";
            desc = "Accept Copilot suggestion or tab";
            icon = "✈️";
          }
          {
            __unkeyed-1 = "<M-Tab>";
            desc = "Insert tab (fallback)";
            icon = "->";
          }
          {
            __unkeyed-1 = "<leader>cq";
            desc = "Toggle Copilot";
            icon = "✈️";
          }
        ];
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/github-copilot"
        ];
      };

      home.file.".config/nvim-init/50-copilot-filetypes.lua".text = ''
        local copilot_filetypes = {
          ${lib.concatStringsSep ",\n          " (
            map (ft: "\"${ft}\"") (
              self.settings.baseFiletypesToEnable ++ self.settings.additionalFiletypesToEnable
            )
          )}
        }

        local copilot_ft_set = {}
        for _, ft in ipairs(copilot_filetypes) do
          copilot_ft_set[ft] = true
        end

        local function toggle_copilot_for_filetype()
          local current_ft = vim.api.nvim_buf_get_option(0, 'filetype')

          if vim.fn.exists(":Copilot") == 0 then
            vim.defer_fn(function()
              if vim.fn.exists(":Copilot") > 0 then
                toggle_copilot_for_filetype()
              end
            end, 100)
            return
          end

          if copilot_ft_set[current_ft] then
            vim.cmd("Copilot enable")
          else
            vim.cmd("Copilot disable")
          end
        end

        vim.api.nvim_create_autocmd({
          "FileType", "BufEnter", "WinEnter", "TabEnter",
          "BufWinEnter", "WinNew", "TabNew", "FocusGained"
        }, {
          pattern = "*",
          callback = function()
            vim.defer_fn(toggle_copilot_for_filetype, 50)
          end,
          desc = "Enable/disable Copilot based on filetype"
        })

        vim.api.nvim_create_autocmd("VimEnter", {
          callback = function()
            vim.defer_fn(toggle_copilot_for_filetype, 200)
          end,
          desc = "Initial Copilot filetype check on startup"
        })
      '';
    };
}
