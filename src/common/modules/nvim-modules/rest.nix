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
  name = "rest";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}

          _G.nx_modules["30-rest-globals"] = function()
            _G.is_http_file = function()
              return vim.bo.filetype == "http"
            end
          end
        '';
        plugins.rest = {
          enable = true;
          enableHttpFiletypeAssociation = true;
          enableTelescope = true;
        };

        plugins.treesitter.grammarPackages = lib.mkIf (self.isModuleEnabled "nvim-modules.treesitter") [
          pkgs.vimPlugins.nvim-treesitter.builtGrammars.http
        ];

        autoCmd = [
          {
            event = [ "FileType" ];
            pattern = [ "http" ];
            callback.__raw = ''
              function()
                vim.keymap.set("n", "<localleader>rr", "<cmd>Rest run<CR>", { desc = "Run request under cursor", buffer = true, silent = true })
                vim.keymap.set("n", "<localleader>re", "<cmd>Telescope rest select_env<CR>", { desc = "Select environment", buffer = true, silent = true })
                vim.keymap.set("n", "<localleader>rs", "<cmd>Rest env show<CR>", { desc = "Show current environment", buffer = true, silent = true })
                vim.keymap.set("n", "<localleader>rc", "<cmd>Rest cookies<CR>", { desc = "Edit cookies", buffer = true, silent = true })
                vim.keymap.set("n", "<localleader>rL", "<cmd>split | Rest logs<CR>", { desc = "Show logs in split", buffer = true, silent = true })
              end
            '';
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<localleader>r";
            group = "REST API";
            icon = "🌐";
            cond.__raw = "function() return _G.is_http_file() end";
          }
          {
            __unkeyed-1 = "<localleader>rr";
            desc = "Run request under cursor";
            icon = "▶️";
            cond.__raw = "function() return _G.is_http_file() end";
          }
          {
            __unkeyed-1 = "<localleader>re";
            desc = "Select environment";
            icon = "🌍";
            cond.__raw = "function() return _G.is_http_file() end";
          }
          {
            __unkeyed-1 = "<localleader>rs";
            desc = "Show current environment";
            icon = "📋";
            cond.__raw = "function() return _G.is_http_file() end";
          }
          {
            __unkeyed-1 = "<localleader>rc";
            desc = "Edit cookies";
            icon = "🍪";
            cond.__raw = "function() return _G.is_http_file() end";
          }
          {
            __unkeyed-1 = "<localleader>rL";
            desc = "Show logs in split";
            icon = "📄";
            cond.__raw = "function() return _G.is_http_file() end";
          }
        ];
      };

      home.packages = with pkgs; [
        curl
      ];
    };
}
