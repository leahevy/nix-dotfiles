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

  unfree = [ "copilot-language-server" ];

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
        copilot-language-server
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
            action = ":lua _G.toggle_copilot_manual()<CR>";
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

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["50-copilot-filetypes"] = function()
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

            local function has_manual_override(bufnr)
              return vim.b[bufnr].copilot_manual_override == true
            end

            local function is_copilot_enabled()
              if vim.fn.exists(":Copilot") == 0 then
                return false
              end
              return vim.g.copilot_enabled == 1 or vim.g.copilot_enabled == true
            end

            local function get_last_state(bufnr)
              return vim.b[bufnr].copilot_last_state
            end

            local function set_last_state(bufnr, state)
              vim.b[bufnr].copilot_last_state = state
            end

            local toggle_timer = nil
            local last_notified_state = nil

            local function toggle_copilot_for_filetype()
              if toggle_timer then
                vim.fn.timer_stop(toggle_timer)
                toggle_timer = nil
              end

              toggle_timer = vim.fn.timer_start(100, function()
                toggle_timer = nil

                local bufnr = vim.api.nvim_get_current_buf()
                local current_ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
                local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')

                if buftype == "prompt" or buftype == "nofile" or current_ft == "TelescopePrompt" then
                  return
                end

                if has_manual_override(bufnr) then
                  return
                end

                if vim.fn.exists(":Copilot") == 0 then
                  return
                end

                local should_be_enabled = copilot_ft_set[current_ft] == true
                local current_state = is_copilot_enabled()

                if should_be_enabled ~= current_state then
                  if should_be_enabled then
                    vim.cmd("Copilot enable")
                    vim.g.copilot_enabled = true
                    if last_notified_state ~= true then
                      vim.defer_fn(function()
                        if current_ft == "" then
                          current_ft = "current buffer"
                        end
                        vim.notify('Auto-enabled for ' .. current_ft, vim.log.levels.INFO, {
                          icon = '✅',
                          title = 'Copilot'
                        })
                      end, 200)
                      last_notified_state = true
                    end
                  else
                    vim.cmd("Copilot disable")
                    vim.g.copilot_enabled = false
                    if last_notified_state ~= false then
                      vim.defer_fn(function()
                        if current_ft == "" then
                          current_ft = "current buffer"
                        end
                        vim.notify('Auto-disabled for ' .. current_ft, vim.log.levels.INFO, {
                          icon = '⚠️',
                          title = 'Copilot'
                        })
                      end, 200)
                      last_notified_state = false
                    end
                  end
                end
              end)
            end

            function _G.toggle_copilot_manual()
              if toggle_timer then
                vim.fn.timer_stop(toggle_timer)
                toggle_timer = nil
              end

              local bufnr = vim.api.nvim_get_current_buf()
              local current_ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')

              local current_state = vim.g.copilot_enabled == 1 or vim.g.copilot_enabled == true

              if current_state then
                vim.cmd('Copilot disable')
                vim.g.copilot_enabled = false
                vim.notify('Manually disabled', vim.log.levels.INFO, {
                  icon = '❌',
                  title = 'Copilot'
                })
                last_notified_state = false
                vim.b[bufnr].copilot_manual_override = true
                vim.b[bufnr].copilot_manual_state = false
                vim.b[bufnr].copilot_force_enable = false
              else
                vim.cmd('Copilot enable')
                vim.g.copilot_enabled = true
                vim.notify('Manually enabled', vim.log.levels.INFO, {
                  icon = '✅',
                  title = 'Copilot'
                })
                last_notified_state = true
                vim.b[bufnr].copilot_manual_override = true
                vim.b[bufnr].copilot_manual_state = true

                if not copilot_ft_set[current_ft] then
                  vim.b[bufnr].copilot_force_enable = true
                end
              end
            end

            vim.api.nvim_create_autocmd({
              "FileType", "BufEnter", "WinEnter", "TabEnter",
              "BufWinEnter", "WinNew", "TabNew", "FocusGained"
            }, {
              pattern = "*",
              callback = function()
                local bufnr = vim.api.nvim_get_current_buf()

                if vim.b[bufnr].copilot_force_enable then
                  vim.defer_fn(function()
                    if vim.fn.exists(":Copilot") > 0 then
                      vim.cmd("Copilot enable")
                      vim.g.copilot_enabled = true
                    end
                  end, 50)
                else
                  vim.defer_fn(toggle_copilot_for_filetype, 50)
                end
              end,
              desc = "Enable/disable Copilot based on filetype"
            })

            vim.api.nvim_create_autocmd("VimEnter", {
              callback = function()
                vim.defer_fn(toggle_copilot_for_filetype, 200)
              end,
              desc = "Initial Copilot filetype check on startup"
            })
          end
        '';
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/github-copilot"
        ];
      };

    };
}
