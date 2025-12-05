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
    homePage = "index.md";
    enableUI = false;
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
              enable = self.settings.enableUI;
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
            __unkeyed-1 = "<leader>wW";
            desc = "Wiki index (split right)";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>wh";
            desc = "Homepage";
            icon = "🏠";
          }
          {
            __unkeyed-1 = "<leader>wH";
            desc = "Homepage (split right)";
            icon = "🏠";
          }
          {
            __unkeyed-1 = "<leader>w<leader>";
            desc = "Search wiki";
            icon = "󰓩";
          }
          {
            __unkeyed-1 = "<leader>wdw";
            desc = "Make today diary note";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>wdy";
            desc = "Make yesterday diary note";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>wdt";
            desc = "Make today diary note (split right)";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>wdm";
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
          {
            __unkeyed-1 = "<leader>wr";
            desc = "Rename note";
            icon = "✏️";
            cond.__raw = "function() return _G.is_obsidian_vault_file() end";
          }
          {
            __unkeyed-1 = "<leader>wn";
            desc = "Go to note";
            icon = "📄";
            cond.__raw = "function() return _G.is_obsidian_vault_file() end";
          }
          {
            __unkeyed-1 = "<leader>wc";
            desc = "Toggle checkbox";
            icon = "☑️";
            cond.__raw = "function() return _G.is_obsidian_vault_file() end";
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
            key = "<leader>wW";
            action = "<cmd>vsplit | ObsidianQuickSwitch<cr>";
            options = {
              desc = "Wiki index (split right)";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wh";
            action.__raw = ''
              function()
                local vault_path = vim.fn.expand('${normalizedVaultPath}')
                local home_page = vault_path .. "/${self.settings.homePage}"
                vim.cmd("edit " .. home_page)
              end
            '';
            options = {
              desc = "Homepage";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wH";
            action.__raw = ''
              function()
                local vault_path = vim.fn.expand('${normalizedVaultPath}')
                local home_page = vault_path .. "/${self.settings.homePage}"
                vim.cmd("vsplit " .. home_page)
              end
            '';
            options = {
              desc = "Homepage (split right)";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>w<leader>";
            action = "<cmd>ObsidianSearch<cr>";
            options = {
              desc = "Search wiki";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wdw";
            action = "<cmd>ObsidianToday<cr>";
            options = {
              desc = "Make today diary note";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wdy";
            action = "<cmd>ObsidianYesterday<cr>";
            options = {
              desc = "Make yesterday diary note";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wdt";
            action = "<cmd>vsplit | ObsidianToday<cr>";
            options = {
              desc = "Make today diary note (split right)";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>wdm";
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
                if _G.is_obsidian_vault_file() then
                  vim.keymap.set("n", "<leader>wr", "<cmd>ObsidianRename<cr>", { desc = "Rename note", buffer = true })
                  vim.keymap.set("n", "<leader>wn", "<cmd>ObsidianNew<cr>", { desc = "Go to note", buffer = true })
                  vim.keymap.set("n", "<leader>wc", "<cmd>ObsidianToggleCheckbox<cr>", { desc = "Toggle checkbox", buffer = true })
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

          _G.nx_modules["40-obsidian-globals"] = function()
            _G.is_obsidian_vault_file = function()
              local file_path = vim.fn.expand('%:p')
              local vault_path = vim.fn.expand('${self.settings.wikiPath}')
              local normalized_file_path = vim.fn.resolve(file_path)
              local normalized_vault_path = vim.fn.resolve(vault_path)
              return string.find(normalized_file_path, normalized_vault_path, 1, true) == 1
            end
          end

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

              _G.obsidian_create_daily_for_date = function(date_str)
                local ok, obsidian = pcall(require, "obsidian")
                if not ok then
                  vim.notify("Plugin not available", vim.log.levels.ERROR, { title = "Obsidian" })
                  return
                end

                local year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
                if not year or not month or not day then
                  vim.notify("Invalid date format: " .. date_str, vim.log.levels.ERROR, { title = "Obsidian" })
                  return
                end

                local timestamp = os.time({
                  year = tonumber(year),
                  month = tonumber(month),
                  day = tonumber(day),
                  hour = 0,
                  min = 0,
                  sec = 0
                })

                local client = obsidian.get_client()
                if not client then
                  vim.notify("Failed to get client", vim.log.levels.ERROR, { title = "Obsidian" })
                  return
                end

                local ok_daily, daily_note = pcall(function()
                  return client:_daily(timestamp)
                end)

                if not ok_daily or not daily_note then
                  vim.notify("Failed to create daily note for " .. date_str, vim.log.levels.ERROR, { title = "Obsidian" })
                  return
                end

                local ok_open, _ = pcall(function()
                  client:open_note(daily_note)
                end)

                if not ok_open then
                  vim.notify("Failed to open daily note for " .. date_str, vim.log.levels.ERROR, { title = "Obsidian" })
                end
              end

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

                  call luaeval('_G.obsidian_create_daily_for_date(_A)', date_str)
                endfunction
              ]])
            end
          ''}
        '';
      };
    };
}
