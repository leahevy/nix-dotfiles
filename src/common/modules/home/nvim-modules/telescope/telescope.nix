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
  name = "telescope";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.telescope = {
          enable = true;
          extensions = {
            fzf-native = {
              enable = true;
            };
          };
          keymaps = {
            "<leader>ff" = {
              action = "find_files";
              options.desc = "Find all files";
            };
            "<leader>fh" = {
              action = "help_tags";
              options.desc = "Help tags";
            };
            "<leader>fr" = {
              action = "oldfiles";
              options.desc = "Recent files";
            };
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader><leader>";
            action = "<cmd>lua local git_root = _G.find_git_root(); if git_root then require('telescope.builtin').git_files() else require('telescope.builtin').find_files() end<CR>";
            options = {
              silent = true;
              desc = "Find files";
            };
          }
          {
            mode = "n";
            key = "<leader>/";
            action = "<cmd>Telescope live_grep<CR>";
            options = {
              silent = true;
              desc = "Search in project";
            };
          }
          {
            mode = "n";
            key = "<leader>b";
            action = "<cmd>Telescope buffers<CR>";
            options = {
              silent = true;
              desc = "Switch buffers";
            };
          }
          {
            mode = "n";
            key = "<leader>J";
            action = "<cmd>Telescope jumplist<CR>";
            options = {
              silent = true;
              desc = "Jump list";
            };
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}

          _G.nx_modules["50-telescope-project"] = function()
            local function find_git_root(path)
              local current = path or vim.fn.expand('%:p:h')
              while current and current ~= '/' do
                if vim.fn.isdirectory(current .. '/.git') == 1 then
                  return current
                end
                current = vim.fn.fnamemodify(current, ':h')
              end
              return nil
            end

            _G.find_git_root = find_git_root

            vim.api.nvim_create_user_command('ProjectFiles', function()
              local git_root = find_git_root() or vim.fn.getcwd()
              require('telescope.builtin').find_files({ cwd = git_root })
            end, {})

            vim.api.nvim_create_user_command('ProjectGrep', function(opts)
              local git_root = find_git_root() or vim.fn.getcwd()
              if opts.args and opts.args ~= "" then
                require('telescope.builtin').grep_string({ search = opts.args, cwd = git_root })
              else
                require('telescope.builtin').live_grep({ cwd = git_root })
              end
            end, { nargs = '?' })
          end

          _G.nx_modules["99-telescope-highlight"] = function()
            local function fix_telescope_background()
              vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
              vim.api.nvim_set_hl(0, "TelescopePromptNormal", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
              vim.api.nvim_set_hl(0, "TelescopeResultsNormal", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
              vim.api.nvim_set_hl(0, "TelescopePreviewNormal", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
              vim.api.nvim_set_hl(0, "TelescopeSelection", { bg = "${self.theme.colors.terminal.normalBackgrounds.selection.html}" })
            end

            vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
              callback = function()
                vim.defer_fn(fix_telescope_background, 100)
              end,
            })
          end

          _G.nx_modules["51-telescope-ui-select"] = function()
            vim.ui.select = function(items, opts, on_choice)
              require("telescope.pickers").new({}, {
                prompt_title = opts.prompt or "Select",
                finder = require("telescope.finders").new_table({
                  results = items,
                  entry_maker = function(entry)
                    return {
                      value = entry,
                      display = entry.name or tostring(entry),
                      ordinal = entry.name or tostring(entry),
                    }
                  end,
                }),
                sorter = require("telescope.config").values.generic_sorter({}),
                attach_mappings = function(prompt_bufnr, map)
                  require("telescope.actions").select_default:replace(function()
                    require("telescope.actions").close(prompt_bufnr)
                    local selection = require("telescope.actions.state").get_selected_entry()
                    if selection then
                      on_choice(selection.value)
                    end
                  end)
                  return true
                end,
              }):find()
            end
          end
        '';
      };

      home.packages = with pkgs; [
        fzf
        ripgrep
        fd
      ];

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<leader>J";
              desc = "Jump list";
              icon = "🦘";
            }
          ];
    };
}
