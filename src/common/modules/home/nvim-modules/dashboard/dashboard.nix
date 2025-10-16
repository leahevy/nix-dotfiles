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
  name = "dashboard";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  defaults = {
    ensureBaseProjects = [
      "$NXCORE_DIR"
      "$NXCONFIG_DIR"
    ];
    ensureProjects = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    let
      projects = self.settings.ensureBaseProjects ++ self.settings.ensureProjects;
    in
    {
      programs.nixvim = {
        plugins.dashboard = {
          enable = true;
          settings = {
            theme = "hyper";
            disable_move = true;
            change_to_vcs_root = true;
            config = {
              header = [
                "                                "
                "                                "
                "       ◢██◣   ◥███◣  ◢██◣       "
                "       ◥███◣   ◥███◣◢███◤       "
                "        ◥███◣   ◥██████◤        "
                "    ◢█████████████████◤   ◢◣    "
                "   ◢██████████████████◣  ◢██◣   "
                "        ◢███◤      ◥███◣◢███◤   "
                "       ◢███◤        ◥██████◤    "
                "◢█████████◤          ◥█████████◣"
                "◥█████████◣          ◢█████████◤"
                "    ◢██████◣        ◢███◤       "
                "   ◢███◤◥███◣      ◢███◤        "
                "   ◥██◤  ◥██████████████████◤   "
                "    ◥◤   ◢█████████████████◤    "
                "        ◢██████◣   ◥███◣        "
                "       ◢███◤◥███◣   ◥███◣       "
                "       ◥██◤  ◥███◣   ◥██◤       "
                "                                "
                "                                "
                "                                "
              ];
              shortcut = [
                {
                  desc = " Find File";
                  group = "@property";
                  action = "Telescope find_files";
                  key = "f";
                }
                {
                  desc = " New File";
                  group = "Number";
                  action = "enew";
                  key = "n";
                }
                {
                  desc = " Recent Files";
                  group = "Label";
                  action = "Telescope oldfiles";
                  key = "r";
                }
                {
                  desc = " Find Text";
                  group = "DiagnosticHint";
                  action = "Telescope live_grep";
                  key = "g";
                }
                {
                  desc = " Core";
                  group = "DiagnosticInfo";
                  action = "lua vim.cmd('cd ' .. vim.env.NXCORE_DIR) vim.cmd('Telescope find_files')";
                  key = "c";
                }
                {
                  desc = " Config";
                  group = "DiagnosticWarn";
                  action = "lua vim.cmd('cd ' .. vim.env.NXCONFIG_DIR) vim.cmd('Telescope find_files')";
                  key = "C";
                }
                {
                  desc = " Quit";
                  group = "DiagnosticError";
                  action = "quit";
                  key = "q";
                }
              ];
              packages = {
                enable = false;
              };
              project = {
                enable = true;
                limit = 8;
                action = "Telescope find_files cwd=";
              };
              mru = {
                limit = 10;
              };
              footer.__raw = ''
                {
                  "",
                  "Configuration activated on " .. os.date("%Y-%m-%d %H:%M", vim.fn.getftime(vim.fn.stdpath("config") .. "/timestamp"))
                }
              '';
            };
          };

        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>d";
            action = ":Dashboard<CR>";
            options = {
              silent = true;
              desc = "Open dashboard";
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>d";
            desc = "Open dashboard";
            icon = "󰕮";
          }
        ];
      };

      home.file.".config/nvim-init/60-dashboard.lua".text = ''
        vim.api.nvim_set_hl(0, "DashboardHeader", { fg = "#e5c075", bold = true })

        vim.api.nvim_set_hl(0, "DashboardProjectTitle", { fg = "#61afef", bold = true })
        vim.api.nvim_set_hl(0, "DashboardProjectTitleIcon", { fg = "#e06c75" })
        vim.api.nvim_set_hl(0, "DashboardProjectIcon", { fg = "#61afef" })
        vim.api.nvim_set_hl(0, "DashboardMruTitle", { fg = "#98c379", bold = true })
        vim.api.nvim_set_hl(0, "DashboardMruIcon", { fg = "#e5c07b" })
        vim.api.nvim_set_hl(0, "DashboardFiles", { fg = "#abb2bf" })
        vim.api.nvim_set_hl(0, "DashboardShortCutIcon", { fg = "#c678dd" })

        local function clean_project_cache()
          local cache_path = vim.fn.stdpath('cache') .. '/dashboard/cache'

          if vim.fn.filereadable(cache_path) ~= 1 then
            return
          end

          local read_ok, data = pcall(function()
            return table.concat(vim.fn.readfile(cache_path), '\n')
          end)

          if read_ok and data and data ~= ''' then
            local load_ok, loaded_func = pcall(loadstring, data)
            if load_ok and loaded_func then
              local exec_ok, result = pcall(loaded_func)
              if exec_ok and type(result) == 'table' then
                local valid_projects = {}
                local seen = {}

                local all_valid = {}
                for _, proj in ipairs(result) do
                  if proj and type(proj) == "string" then
                    local has_bad_tilde = proj:match("~") and not proj:match("^~/")
                    local home_dir = vim.fn.expand("~")
                    local has_bad_home = proj:find(home_dir, 2, true) ~= nil
                    local is_basic_invalid = proj == "." or proj == ".." or proj == ""

                    if not has_bad_tilde and not has_bad_home and not is_basic_invalid and vim.fn.isdirectory(proj) == 1 then
                      local abs_proj = vim.fn.fnamemodify(proj, ':p')
                      if abs_proj and abs_proj ~= "/" and abs_proj ~= vim.fn.expand("~") then
                        table.insert(all_valid, {original = proj, expanded = abs_proj})
                      end
                    end
                  end
                end

                local function get_path_tail(path, n)
                  local segments = {}
                  for segment in path:gmatch("[^/]+") do
                    table.insert(segments, segment)
                  end
                  local start_idx = math.max(1, #segments - n + 1)
                  local tail_segments = {}
                  for i = start_idx, #segments do
                    table.insert(tail_segments, segments[i])
                  end
                  return table.concat(tail_segments, "/")
                end

                for _, proj in ipairs(all_valid) do
                  local should_keep = true

                  for _, other in ipairs(all_valid) do
                    if proj.expanded ~= other.expanded then
                      local proj_path = proj.expanded:gsub("/$", "") .. "/"
                      local other_path = other.expanded:gsub("/$", "") .. "/"

                      if vim.startswith(proj_path, other_path) then
                        should_keep = false
                        break
                      end

                      local proj_tail = get_path_tail(proj.expanded, 3)
                      local other_tail = get_path_tail(other.expanded, 3)

                      if proj_tail ~= "" and proj_tail == other_tail then
                        if #proj.expanded > #other.expanded then
                          should_keep = false
                          break
                        end
                      end
                    end
                  end

                  if should_keep and not seen[proj.expanded] then
                    table.insert(valid_projects, proj.expanded)
                    seen[proj.expanded] = true
                  end
                end

                local write_ok = pcall(function()
                  local code = 'return ' .. vim.inspect(valid_projects)
                  local handle = io.open(cache_path, 'w')
                  if handle then
                    handle:write(code)
                    handle:close()
                  end
                end)
              end
            end
          end
        end

        local function add_project_to_cache(project_path)
          if not project_path or project_path == "." or project_path == ".." or project_path == "" then
            return
          end

          local expanded_path = vim.fn.expand(project_path)
          local abs_path = vim.fn.fnamemodify(expanded_path, ':p')
          if not abs_path or abs_path == "/" or abs_path == vim.fn.expand("~") then
            return
          end

          if vim.fn.isdirectory(abs_path) ~= 1 then
            return
          end

          local cache_path = vim.fn.stdpath('cache') .. '/dashboard/cache'

          local ok = pcall(vim.fn.mkdir, vim.fn.stdpath('cache') .. '/dashboard', 'p')
          if not ok then
            return
          end

          local projects = {}

          if vim.fn.filereadable(cache_path) == 1 then
            local read_ok, data = pcall(function()
              return table.concat(vim.fn.readfile(cache_path), '\n')
            end)

            if read_ok and data and data ~= ''' then
              local load_ok, loaded_func = pcall(loadstring, data)
              if load_ok and loaded_func then
                local exec_ok, result = pcall(loaded_func)
                if exec_ok and type(result) == 'table' then
                  local valid_projects = {}
                  for _, proj in ipairs(result) do
                    if proj and type(proj) == "string" then
                      local expanded = vim.fn.expand(proj)
                      local abs_proj = vim.fn.fnamemodify(expanded, ':p')

                      if abs_proj and abs_proj ~= "/" and abs_proj ~= vim.fn.expand("~")
                         and vim.fn.isdirectory(abs_proj) == 1 then
                        table.insert(valid_projects, abs_proj)
                      end
                    end
                  end
                  projects = valid_projects
                end
              end
            end
          end

          local function get_path_tail(path, n)
            local segments = {}
            for segment in path:gmatch("[^/]+") do
              table.insert(segments, segment)
            end
            local start_idx = math.max(1, #segments - n + 1)
            local tail_segments = {}
            for i = start_idx, #segments do
              table.insert(tail_segments, segments[i])
            end
            return table.concat(tail_segments, "/")
          end

          local should_add = true
          local to_remove = {}

          for i, existing in ipairs(projects) do
            if existing == abs_path then
              return
            end

            local abs_path_with_slash = abs_path:gsub("/$", "") .. "/"
            local existing_with_slash = existing:gsub("/$", "") .. "/"

            if vim.startswith(abs_path_with_slash, existing_with_slash) then
              should_add = false
              break
            elseif vim.startswith(existing_with_slash, abs_path_with_slash) then
              table.insert(to_remove, i)
            else
              local new_tail = get_path_tail(abs_path, 3)
              local existing_tail = get_path_tail(existing, 3)

              if new_tail ~= "" and new_tail == existing_tail then
                if #abs_path > #existing then
                  should_add = false
                  break
                else
                  table.insert(to_remove, i)
                end
              end
            end
          end

          for i = #to_remove, 1, -1 do
            table.remove(projects, to_remove[i])
          end

          if should_add then
            table.insert(projects, 1, abs_path)
          end

          if #projects > 8 then
            projects = vim.list_slice(projects, 1, 8)
          end

          local write_ok = pcall(function()
            local code = 'return ' .. vim.inspect(projects)
            local handle = io.open(cache_path, 'w')
            if handle then
              handle:write(code)
              handle:close()
            end
          end)
        end

        vim.api.nvim_create_user_command('DashboardAddProject', function(opts)
          local path = opts.args ~= ''' and opts.args or vim.fn.getcwd()
          add_project_to_cache(path)
          print('Added project: ' .. path)
        end, { nargs = '?', complete = 'dir' })

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

        vim.api.nvim_create_autocmd({'DirChanged', 'BufEnter'}, {
          callback = function()
            local cwd = vim.fn.getcwd()
            if vim.fn.isdirectory(cwd .. '/.git') == 1 then
              add_project_to_cache(cwd)
            end

            local git_root = find_git_root()
            if git_root then
              add_project_to_cache(git_root)
            end
          end,
        })

        local ensure_projects = {${
          if projects == [ ] then
            ""
          else
            ''"${builtins.concatStringsSep ''", "'' (map (p: builtins.toString p) projects)}"''
        }}

        for _, project_path in ipairs(ensure_projects) do
          local expanded_path = vim.fn.expand(project_path)
          if vim.fn.isdirectory(expanded_path) == 1 then
            add_project_to_cache(expanded_path)
          end
        end

        clean_project_cache()
      '';
    };
}
