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
  name = "gitsigns";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  assertions = [
    {
      assertion = !(self.isModuleEnabled "nvim-modules.gitgutter");
      message = "gitsigns and gitgutter cannot be enabled at the same time.";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.gitsigns = {
          enable = true;
          settings = {
            signs = {
              add = {
                text = "+";
              };
              change = {
                text = "*";
              };
              delete = {
                text = "-";
              };
              topdelete = {
                text = "-";
              };
              changedelete = {
                text = "*";
              };
              untracked = {
                text = "┆";
              };
            };
            signs_staged = {
              add = {
                text = "+";
              };
              change = {
                text = "*";
              };
              delete = {
                text = "-";
              };
              topdelete = {
                text = "-";
              };
              changedelete = {
                text = "*";
              };
              untracked = {
                text = "┆";
              };
            };
            signs_staged_enable = true;
            signcolumn = true;
            current_line_blame = true;
            current_line_blame_opts = {
              delay = 100;
            };
            sign_priority = 20;
            watch_gitdir = {
              follow_files = true;
            };
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>gp";
            action = "<cmd>lua require('gitsigns').preview_hunk()<CR>";
            options = {
              silent = true;
              desc = "Preview hunk";
            };
          }
          {
            mode = "n";
            key = "<leader>gs";
            action = "<cmd>lua require('gitsigns').stage_hunk()<CR>";
            options = {
              silent = true;
              desc = "Stage hunk";
            };
          }
          {
            mode = "n";
            key = "<leader>gu";
            action = "<cmd>lua require('gitsigns').reset_hunk()<CR>";
            options = {
              silent = true;
              desc = "Undo hunk";
            };
          }
          {
            mode = "v";
            key = "<leader>gs";
            action = "<cmd>lua require('gitsigns').stage_hunk({vim.fn.line('.'), vim.fn.line('v')})<CR>";
            options = {
              silent = true;
              desc = "Stage hunk";
            };
          }
          {
            mode = "v";
            key = "<leader>gu";
            action = "<cmd>lua require('gitsigns').reset_hunk({vim.fn.line('.'), vim.fn.line('v')})<CR>";
            options = {
              silent = true;
              desc = "Undo hunk";
            };
          }
          {
            mode = "n";
            key = "]h";
            action = "<cmd>lua require('gitsigns').next_hunk()<CR>";
            options = {
              silent = true;
              desc = "Next hunk";
            };
          }
          {
            mode = "n";
            key = "[h";
            action = "<cmd>lua require('gitsigns').prev_hunk()<CR>";
            options = {
              silent = true;
              desc = "Previous hunk";
            };
          }
          {
            mode = "n";
            key = "<leader>gb";
            action = "<cmd>Gitsigns blame<CR>";
            options = {
              silent = true;
              desc = "Git blame";
            };
          }
          {
            mode = "n";
            key = "<leader>gB";
            action = "<cmd>lua require('gitsigns').blame_line()<CR>";
            options = {
              silent = true;
              desc = "Blame line";
            };
          }
          {
            mode = "n";
            key = "<leader>gd";
            action = "<cmd>lua require('gitsigns').diffthis()<CR>";
            options = {
              silent = true;
              desc = "Diff this";
            };
          }
          {
            mode = "n";
            key = "<leader>gD";
            action = "<cmd>lua _G.gitsigns_telescope_diffthis()<CR>";
            options = {
              silent = true;
              desc = "Diff with revision (telescope)";
            };
          }
          {
            mode = "n";
            key = "<leader>gC";
            action = "<cmd>lua _G.gitsigns_telescope_diff_branch()<CR>";
            options = {
              silent = true;
              desc = "Diff with branch (telescope)";
            };
          }
          {
            mode = "n";
            key = "<leader>gS";
            action = "<cmd>lua require('gitsigns').stage_buffer()<CR>";
            options = {
              silent = true;
              desc = "Stage buffer";
            };
          }
          {
            mode = "n";
            key = "<leader>gU";
            action = "<cmd>lua require('gitsigns').reset_buffer()<CR>";
            options = {
              silent = true;
              desc = "Reset buffer";
            };
          }
          {
            mode = "n";
            key = "<leader>gt";
            action = "<cmd>lua _G.gitsigns_toggle_blame_with_notify()<CR>";
            options = {
              silent = true;
              desc = "Toggle blame";
            };
          }
        ];

        autoCmd = [
          {
            event = "FileType";
            pattern = "gitsigns-blame";
            callback.__raw = ''
              function()
                vim.keymap.set('n', 'q', ':close<CR>', { buffer = true, silent = true })
              end
            '';
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>g";
            group = "git";
            icon = "⇡";
          }
          {
            __unkeyed-1 = "<leader>gp";
            desc = "Preview hunk";
            icon = "󰐕";
          }
          {
            __unkeyed-1 = "<leader>gs";
            desc = "Stage hunk";
            icon = "󰐕";
          }
          {
            __unkeyed-1 = "<leader>gu";
            desc = "Undo hunk";
            icon = "󰐕";
          }
          {
            __unkeyed-1 = "]h";
            desc = "Next hunk";
            icon = "";
          }
          {
            __unkeyed-1 = "[h";
            desc = "Previous hunk";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gb";
            desc = "Git blame";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gB";
            desc = "Blame line";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gd";
            desc = "Diff this";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gD";
            desc = "Diff with revision (telescope)";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gC";
            desc = "Diff with branch (telescope)";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gS";
            desc = "Stage buffer";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gU";
            desc = "Reset buffer";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gt";
            desc = "Toggle blame";
            icon = "";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["50-gitsigns"] = function()
            local function set_gitsigns_colors()
              vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = "${self.theme.colors.semantic.success.html}" })
              vim.api.nvim_set_hl(0, "GitSignsChange", { fg = "${self.theme.colors.semantic.warning.html}" })
              vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = "${self.theme.colors.semantic.error.html}" })
              vim.api.nvim_set_hl(0, "GitSignsTopdelete", { fg = "${self.theme.colors.semantic.error.html}" })
              vim.api.nvim_set_hl(0, "GitSignsChangedelete", { fg = "${self.theme.colors.semantic.info.html}" })
              vim.api.nvim_set_hl(0, "GitSignsUntracked", { fg = "${self.theme.colors.separators.normal.html}" })

              vim.api.nvim_set_hl(0, "GitSignsStagedAdd", { fg = "${self.theme.colors.semantic.successDarker.html}" })
              vim.api.nvim_set_hl(0, "GitSignsStagedChange", { fg = "${self.theme.colors.semantic.warningDarker.html}" })
              vim.api.nvim_set_hl(0, "GitSignsStagedDelete", { fg = "${self.theme.colors.semantic.errorDarker.html}" })
              vim.api.nvim_set_hl(0, "GitSignsStagedTopdelete", { fg = "${self.theme.colors.semantic.errorDarker.html}" })
              vim.api.nvim_set_hl(0, "GitSignsStagedChangedelete", { fg = "${self.theme.colors.semantic.infoDarker.html}" })
              vim.api.nvim_set_hl(0, "GitSignsStagedUntracked", { fg = "${self.theme.colors.separators.normal.html}" })

              vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", { fg = "${self.theme.colors.separators.ultraDark.html}", underline = false, sp = "${self.theme.colors.separators.ultraDark.html}" })
            end

            vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
              callback = function()
                vim.defer_fn(set_gitsigns_colors, 100)
              end,
            })

            _G.gitsigns_telescope_diffthis = function()
              local telescope = require('telescope.builtin')
              local actions = require('telescope.actions')
              local action_state = require('telescope.actions.state')

              telescope.git_commits({
                previewer = false,
                attach_mappings = function(prompt_bufnr, map)
                  actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection then
                      require('gitsigns').diffthis(selection.value)
                      vim.notify("Diffing against commit: " .. selection.value:sub(1,8), vim.log.levels.INFO, {
                        icon = "🔍",
                        title = "Git"
                      })
                    end
                  end)
                  return true
                end,
              })
            end

            _G.gitsigns_telescope_diff_branch = function()
              local telescope = require('telescope.builtin')
              local actions = require('telescope.actions')
              local action_state = require('telescope.actions.state')

              telescope.git_branches({
                show_remote_tracking_branches = true,
                attach_mappings = function(prompt_bufnr, map)
                  actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection then
                      require('gitsigns').diffthis(selection.value)
                      vim.notify("Diffing against branch: " .. selection.value, vim.log.levels.INFO, {
                        icon = "🌿",
                        title = "Git"
                      })
                    end
                  end)
                  return true
                end,
              })
            end

            _G.gitsigns_toggle_blame_with_notify = function()
              require('gitsigns').toggle_current_line_blame()
              vim.defer_fn(function()
                local is_enabled = require('gitsigns.config').config.current_line_blame
                local status = is_enabled and "enabled" or "disabled"
                local icon = is_enabled and "👁️" or "👁️‍🗨️"
                vim.notify("Line blame " .. status, vim.log.levels.INFO, {
                  icon = icon,
                  title = "Git"
                })
              end, 50)
            end
          end
        '';
      };
    };
}
