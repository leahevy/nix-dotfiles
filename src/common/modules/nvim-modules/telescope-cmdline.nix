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
  name = "telescope-cmdline";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enable = true;

    picker = {
      layout_config = {
        width = 120;
        height = 25;
      };
    };

    mappings = {
      complete = "<Tab>";
      run_selection = "<M-CR>";
      run_input = "<CR>";
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = [
          (pkgs.vimUtils.buildVimPlugin {
            name = "telescope-cmdline";
            src = pkgs.fetchFromGitHub {
              owner = "jonarrien";
              repo = "telescope-cmdline.nvim";
              rev = "7106ff7357d9d3cde3e71cd8fe8998d2f96a1bdd";
              hash = "sha256-xpgWxjng4X1LapjuJkhVM7gQbpiZ9pS6fTy+L2Y8IM8=";
            };
            dependencies = with pkgs.vimPlugins; [
              telescope-nvim
              plenary-nvim
            ];
          })
        ];

        keymaps = [
          {
            mode = "n";
            key = ";";
            action = "<cmd>Telescope cmdline<CR>";
            options = {
              desc = "Open telescope cmdline";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<M-;>";
            action = ":";
            options = {
              desc = "Command mode";
              silent = false;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = ";";
            desc = "Open telescope cmdline";
            icon = "🔍";
          }
          {
            __unkeyed-1 = "<M-;>";
            desc = "Command mode";
            icon = ":";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["75-telescope-cmdline"] = function()
            local has_telescope, telescope = pcall(require, 'telescope')
            if not has_telescope then
              return
            end

            telescope.setup({
              extensions = {
                cmdline = {
                  picker = {
                    layout_config = {
                      width = ${toString self.settings.picker.layout_config.width},
                      height = ${toString self.settings.picker.layout_config.height}
                    }
                  },
                  mappings = {
                    complete = '${self.settings.mappings.complete}',
                    run_selection = '${self.settings.mappings.run_selection}',
                    run_input = '${self.settings.mappings.run_input}'
                  },
                  overseer = {
                    enabled = ${if self.isModuleEnabled "nvim-modules.overseer" then "true" else "false"}
                  },
                  output_pane = {
                    enabled = false,
                    min_lines = 3,
                    max_height = 25
                  }
                }
              }
            })

            pcall(telescope.load_extension, 'cmdline')

            vim.api.nvim_create_autocmd("FileType", {
              pattern = "man",
              callback = function()
                vim.keymap.set('n', ';', ':', { buffer = true, silent = false, desc = "Command mode (man buffer)" })
              end,
            })

            local has_cmdline_actions, cmdline_actions = pcall(require, 'cmdline.actions')
            if has_cmdline_actions then
              local original_run = cmdline_actions.run_input
              local original_run_selection = cmdline_actions.run_selection

              local function is_save_command(cmd)
                if not cmd then return false end
                local trimmed = vim.trim(cmd)
                return trimmed == "w" or trimmed == "write" or
                       trimmed:match("^w%s") or trimmed:match("^write%s") or
                       trimmed:match("^w!") or trimmed:match("^write!")
              end

              local function wrap_run_function(original_fn)
                return function(prompt_bufnr)
                  local action_state = require("telescope.actions.state")
                  local picker = action_state.get_current_picker(prompt_bufnr)
                  local input = picker:_get_prompt()
                  local selection = action_state.get_selected_entry()
                  local cmd = selection and selection.cmd or vim.trim(input or "")

                  if is_save_command(cmd) then
                    local orig_notify = vim.notify
                    vim.notify = function(msg, level, opts)
                      if type(msg) == "string" and (
                        msg:match('"%S+" %d+L, %d+B written') or
                        msg:match('written$') or
                        msg:match('%d+L, %d+B')
                      ) then
                        return
                      end
                      return orig_notify(msg, level, opts)
                    end

                    local result = original_fn(prompt_bufnr)

                    vim.notify = orig_notify
                    return result
                  else
                    return original_fn(prompt_bufnr)
                  end
                end
              end

              local function enhance_run_function(original_fn)
                return function(prompt_bufnr)
                  local action_state = require("telescope.actions.state")
                  local picker = action_state.get_current_picker(prompt_bufnr)
                  local input = picker:_get_prompt()
                  local selection = action_state.get_selected_entry()
                  local cmd = selection and selection.cmd or vim.trim(input or "")

                  if is_save_command(cmd) then
                    local orig_notify = vim.notify
                    vim.notify = function(msg, level, opts)
                      if type(msg) == "string" and (
                        msg:match('"%S+" %d+L, %d+B written') or
                        msg:match('written$') or
                        msg:match('%d+L, %d+B')
                      ) then
                        return
                      end
                      return orig_notify(msg, level, opts)
                    end

                    local result = original_fn(prompt_bufnr)
                    vim.notify = orig_notify
                    return result
                  else
                    local orig_notify = vim.notify
                    vim.notify = function(msg, level, opts)
                      if type(msg) == "string" and msg ~= "" then
                        local icon = "⚡"
                        opts = opts or {}
                        if not opts.title then
                          opts.title = "Command Output"
                        end
                        if not opts.icon then
                          opts.icon = icon
                        end
                        return orig_notify(msg, level, opts)
                      end
                      return orig_notify(msg, level, opts)
                    end

                    local result = original_fn(prompt_bufnr)
                    vim.notify = orig_notify
                    return result
                  end
                end
              end

              cmdline_actions.run_input = enhance_run_function(original_run)
              cmdline_actions.run_selection = enhance_run_function(original_run_selection)
            end
          end
        '';
      };
    };
}
