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
                  "Config built: " .. os.date("%Y-%m-%d %H:%M", vim.fn.getftime(vim.fn.stdpath("config") .. "/timestamp"))
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

        local function add_project_to_cache(project_path)
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
                  projects = result
                end
              end
            end
          end

          for _, existing in ipairs(projects) do
            if existing == project_path then
              return
            end
          end

          table.insert(projects, 1, project_path)

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
      '';
    };
}
