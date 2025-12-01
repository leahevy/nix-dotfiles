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
  name = "obsidian";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    wikiPath = "~/.local/share/nvim/wiki/";
  };

  assertions = [
    {
      assertion = !(self.isModuleEnabled "nvim-modules.vimwiki");
      message = "obsidian and vimwiki modules are mutually exclusive!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      normalizedVaultPath =
        let
          path = self.settings.wikiPath;
          homePrefix = "$HOME";
        in
        if lib.hasPrefix homePrefix path then "~" + lib.removePrefix homePrefix path else path;

      customPkgs = self.pkgs {
        overlays = [
          (final: prev: {
            vimPlugins = prev.vimPlugins // {
              obsidian-nvim = prev.vimPlugins.obsidian-nvim.overrideAttrs (oldAttrs: {
                nvimSkipModules = (oldAttrs.nvimSkipModules or [ ]) ++ [ "obsidian.pickers._fzf" ];
              });
            };
          })
        ];
      };
    in
    {
      programs.nixvim = {
        plugins.obsidian = {
          enable = true;
          package = customPkgs.vimPlugins.obsidian-nvim;
          settings = {
            workspaces = [
              {
                name = "default";
                path = normalizedVaultPath;
              }
            ];
            new_notes_location = "current_dir";
            preferred_link_style = "wiki";
            wiki_link_func = "use_alias_only";
            note_id_func.__raw = ''
              function(title)
                local suffix = ""
                if title ~= nil then
                  suffix = title:gsub(" ", "_"):gsub("[^A-Za-z0-9_-]", ""):lower()
                else
                  suffix = tostring(os.time())
                end
                return suffix
              end
            '';
            frontmatter = {
              enabled = true;
            };
            attachments = {
              img_folder = "attachments";
              confirm_img_paste = true;
            };
            search = {
              sort_by = "modified";
              sort_reversed = true;
              max_lines = 200;
            };
            completion = {
              nvim_cmp = true;
              min_chars = 2;
              create_new = true;
            };
            daily_notes = {
              folder = "diary";
              date_format = "%Y-%m-%d";
              alias_format = "%B %-d, %Y";
              template = null;
            };
            picker = {
              name = "telescope.nvim";
              note_mappings = {
                new = "<C-x>";
                insert_link = "<C-l>";
              };
              tag_mappings = {
                tag_note = "<C-x>";
                insert_tag = "<C-l>";
              };
            };
            ui = {
              enable = true;
              checkboxes = {
                " " = {
                  char = "󰄱";
                  hl_group = "ObsidianTodo";
                };
                "x" = {
                  char = "✓";
                  hl_group = "ObsidianDone";
                };
              };
            };
          };
        };

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>w";
            group = "wiki";
            icon = "󰖬";
          }
          {
            __unkeyed-1 = "<leader>ww";
            desc = "Wiki index";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>wi";
            desc = "Diary index";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>wt";
            desc = "Wiki in new tab";
            icon = "󰓩";
          }
          {
            __unkeyed-1 = "<leader>ws";
            desc = "Search wiki";
            icon = "󰓩";
          }
          {
            __unkeyed-1 = "<leader>wd";
            desc = "Wiki diary";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>w<leader>w";
            desc = "Make today diary note";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>w<leader>y";
            desc = "Make yesterday diary note";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>w<leader>t";
            desc = "Make today diary note (new tab)";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>w<leader>m";
            desc = "Make tomorrow diary note";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>wD";
            desc = "Search diary";
            icon = "🔍";
          }
          {
            __unkeyed-1 = "<leader>wT";
            desc = "Browse tags";
            icon = "🏷️";
          }
          {
            __unkeyed-1 = "<leader>wu";
            desc = "Insert referenced note links";
            icon = "❓";
          }
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>ww";
            action = "<cmd>ObsidianQuickSwitch<cr>";
            options = {
              desc = "Wiki index";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wi";
            action = "<cmd>ObsidianDailies -365<cr>";
            options = {
              desc = "Diary index";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wt";
            action = "<cmd>tabnew | ObsidianQuickSwitch<cr>";
            options = {
              desc = "Wiki in new tab";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>ws";
            action = "<cmd>ObsidianSearch<cr>";
            options = {
              desc = "Search wiki";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wd";
            action = "<cmd>ObsidianToday<cr>";
            options = {
              desc = "Wiki diary";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>w<leader>w";
            action = "<cmd>ObsidianToday<cr>";
            options = {
              desc = "Make diary note";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>w<leader>y";
            action = "<cmd>ObsidianYesterday<cr>";
            options = {
              desc = "Make yesterday diary note";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>w<leader>t";
            action = "<cmd>tabnew | ObsidianToday<cr>";
            options = {
              desc = "Make diary note (tab)";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>w<leader>m";
            action = "<cmd>ObsidianTomorrow<cr>";
            options = {
              desc = "Make tomorrow diary note";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wD";
            action.__raw = ''
              function()
                local diary_dir = vim.fn.expand('${normalizedVaultPath}') .. "/diary"
                require('telescope.builtin').live_grep({
                  prompt_title = "Search Diary",
                  search_dirs = { diary_dir },
                  additional_args = function()
                    return { "--type", "md" }
                  end
                })
              end
            '';
            options = {
              desc = "Search diary";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wT";
            action = "<cmd>ObsidianTags<cr>";
            options = {
              desc = "Browse tags";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wu";
            action.__raw = "function() _G.obsidian_insert_linked_note() end";
            options = {
              desc = "Insert referenced note links";
              silent = true;
            };
          }
          {
            mode = "i";
            key = "<C-k>";
            action.__raw = "function() _G.obsidian_insert_existing_note() end";
            options = {
              desc = "Insert link to existing note";
              silent = true;
            };
          }
          {
            mode = "i";
            key = "<C-q>";
            action.__raw = "function() _G.obsidian_insert_linked_note() end";
            options = {
              desc = "Insert referenced note link";
              silent = true;
            };
          }
        ];

        autoCmd = [
          {
            event = [ "BufEnter" ];
            pattern = [ "*.md" ];
            callback.__raw = ''
              function()
                local file_path = vim.fn.expand('%:p')
                local vault_path = vim.fn.expand('${normalizedVaultPath}')
                local is_in_vault = string.find(file_path, vault_path, 1, true) == 1

                if is_in_vault then
                  vim.keymap.set("n", "<leader>wr", "<cmd>ObsidianRename<cr>", { desc = "Rename note", buffer = true })
                  vim.keymap.set("n", "<leader>wn", "<cmd>ObsidianNew<cr>", { desc = "Go to note", buffer = true })
                  vim.keymap.set("n", "<leader>wc", function()
                    return require("obsidian").util.toggle_checkbox()
                  end, { expr = true, desc = "Toggle checkbox", buffer = true })
                  vim.keymap.set("n", "<CR>", function()
                    return require("obsidian").util.gf_passthrough()
                  end, { expr = true, desc = "Follow link", buffer = true })
                end
              end
            '';
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}

          _G.nx_modules["45-obsidian-unlinked"] = function()
            _G.obsidian_insert_linked_note = function()
              local saved_row, saved_col = unpack(vim.api.nvim_win_get_cursor(0))
              local was_insert = vim.fn.mode() == 'i'

              local vault_path = vim.fn.expand('${normalizedVaultPath}')

              require('telescope.builtin').grep_string({
                prompt_title = "Insert Link to Referenced Note",
                cwd = vault_path,
                search = "\\[\\[[^\\]]+\\]\\]",
                use_regex = true,
                additional_args = function()
                  return { "--type", "md" }
                end,
                attach_mappings = function(prompt_bufnr, map)
                  local actions = require('telescope.actions')
                  local action_state = require('telescope.actions.state')

                  actions.select_default:replace(function()
                    local entry = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)

                    local text = entry.text or ""
                    local note_name = text:match("%[%[([^%]]+)%]%]")

                    if note_name then
                      local link = " [[" .. note_name .. "]]"
                      local current_row, current_col = unpack(vim.api.nvim_win_get_cursor(0))
                      vim.api.nvim_buf_set_text(0, current_row - 1, current_col, current_row - 1, current_col, { link })
                      vim.api.nvim_win_set_cursor(0, { current_row, current_col + #link })
                      if was_insert then
                        vim.api.nvim_feedkeys("a", "n", false)
                      end
                    else
                      vim.notify("Could not extract note name from: " .. text, vim.log.levels.WARN)
                    end
                  end)

                  return true
                end,
              })
            end

            _G.obsidian_insert_existing_note = function()
              local saved_row, saved_col = unpack(vim.api.nvim_win_get_cursor(0))
              local was_insert = vim.fn.mode() == 'i'

              local vault_path = vim.fn.expand('${normalizedVaultPath}')
              require('telescope.builtin').find_files({
                prompt_title = "Insert Link to Note",
                cwd = vault_path,
                find_command = { "fd", "--type", "f", "--extension", "md" },
                attach_mappings = function(prompt_bufnr, map)
                  local actions = require('telescope.actions')
                  local action_state = require('telescope.actions.state')

                  actions.select_default:replace(function()
                    local entry = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)

                    local note_name = vim.fn.fnamemodify(entry.value, ":t:r")
                    local link = " [[" .. note_name .. "]]"
                    local current_row, current_col = unpack(vim.api.nvim_win_get_cursor(0))
                    vim.api.nvim_buf_set_text(0, current_row - 1, current_col, current_row - 1, current_col, { link })
                    vim.api.nvim_win_set_cursor(0, { current_row, current_col + #link })
                    if was_insert then
                      vim.api.nvim_feedkeys("a", "n", false)
                    end
                  end)

                  return true
                end,
              })
            end
          end

          ${lib.optionalString (self.isModuleEnabled "nvim-modules.calendar") ''
            _G.nx_modules["50-obsidian-calendar"] = function()
              vim.g.calendar_diary = vim.fn.expand('${normalizedVaultPath}') .. "/diary"
              vim.g.calendar_diary_extension = ".md"
              vim.g.calendar_action = "ObsidianCalendarAction"
              vim.g.calendar_sign = "ObsidianCalendarSign"

              vim.cmd([[
                function! ObsidianCalendarSign(day, month, year)
                  let diary_dir = expand('${normalizedVaultPath}') . "/diary"
                  let date_str = printf("%04d-%02d-%02d", a:year, a:month, a:day)
                  let diary_file = diary_dir . "/" . date_str . ".md"

                  if filereadable(diary_file)
                    return 1
                  else
                    return 0
                  endif
                endfunction

                function! ObsidianCalendarAction(day, month, year, week, dir)
                  let date_str = printf("%04d-%02d-%02d", a:year, a:month, a:day)
                  let diary_dir = expand('${normalizedVaultPath}') . "/diary"
                  let diary_file = diary_dir . "/" . date_str . ".md"

                  if winnr('#') == 0
                    if a:dir ==? 'V'
                      vsplit
                    else
                      split
                    endif
                  else
                    wincmd p
                    if !&hidden && &modified
                      new
                    endif
                  endif

                  call mkdir(diary_dir, "p")
                  execute "edit " . diary_file
                endfunction
              ]])
            end
          ''}
        '';
      };
    };
}
