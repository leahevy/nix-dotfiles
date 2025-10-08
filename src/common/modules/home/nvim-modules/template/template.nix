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
  name = "template";

  defaults = {
    templates = [ ];

    baseTemplates = [
      {
        name = "nix-module";
        shortcut = "n";
        extension = "nix";
        icon = "󱃗";
        autoInsert = {
          pattern = "*.nix";
          pathFilter = "~/.config/nx";
        };
        template = builtins.readFile "${defs.rootPath}/templates/modules/module.nix";
      }
    ];
  };

  configuration =
    context@{ config, options, ... }:
    let
      allTemplates = self.settings.templates ++ self.settings.baseTemplates;

      templateDir = ".local/share/nvim/templates";

      normalizeHomePath =
        path:
        let
          homePrefix = "$HOME";
        in
        if lib.hasPrefix homePrefix path then "~" + lib.removePrefix homePrefix path else path;

      templateFiles = lib.listToAttrs (
        lib.flatten (
          map (
            template:
            let
              sanitizedName = lib.replaceStrings [ "-" "_" ] [ "" "" ] template.name;
              hasCursor = lib.hasInfix "{{_cursor_}}" template.template;
              processedTemplate =
                if hasCursor then
                  template.template
                else
                  let
                    lines = lib.splitString "\n" template.template;
                    firstLine = lib.head lines;
                    restLines = lib.tail lines;
                    modifiedFirstLine = firstLine + "{{_cursor_}}";
                  in
                  lib.concatStringsSep "\n" ([ modifiedFirstLine ] ++ restLines);
              rawTemplate = lib.replaceStrings [ "{{_cursor_}}" ] [ "" ] template.template;
            in
            [
              {
                name = "${templateDir}/${template.extension}/${sanitizedName}.tpl";
                value = {
                  text = ";; ${template.extension}\n${processedTemplate}";
                };
              }
              {
                name = "${templateDir}/${template.extension}/${sanitizedName}-raw.md";
                value = {
                  text = rawTemplate;
                };
              }
            ]
          ) allTemplates
        )
      );

      templateKeybindings = lib.flatten (
        map (
          template:
          let
            sanitizedName = lib.replaceStrings [ "-" "_" ] [ "" "" ] template.name;
          in
          [
            {
              key = "<leader>y${template.shortcut}";
              action = "<cmd>set ft=${template.extension}<cr><cmd>Template ${sanitizedName}<cr>";
              mode = [ "n" ];
              options = {
                silent = true;
                desc = template.name;
              };
            }
            {
              key = "<leader>y<leader>${template.shortcut}";
              action = "<cmd>r ${config.home.homeDirectory}/${templateDir}/${template.extension}/${sanitizedName}-raw.md<cr>";
              mode = [ "n" ];
              options = {
                silent = true;
                desc = "${template.name} (raw)";
              };
            }
          ]
        ) allTemplates
      );

      templateWhichKeySpecs = lib.flatten (
        map (template: [
          {
            __unkeyed-1 = "<leader>y${template.shortcut}";
            desc = template.name;
            icon = if template ? icon then template.icon else "󰷈";
          }
          {
            __unkeyed-1 = "<leader>y<leader>${template.shortcut}";
            desc = "${template.name} (raw)";
            icon = if template ? icon then template.icon else "󰷈";
          }
        ]) allTemplates
      );

      autoInsertTemplates = lib.filter (template: template ? autoInsert) (
        self.settings.templates ++ self.settings.baseTemplates
      );

    in
    {
      home.file = templateFiles // {
        ".config/nvim-init/90-templates.lua".text = ''
          require('template').setup({
            temp_dir = "${config.home.homeDirectory}/${templateDir}",
            author = "${self.user.fullname}",
            email = "${self.user.email}",
          })

          ${lib.concatMapStringsSep "\n" (
            template:
            let
              sanitizedName = lib.replaceStrings [ "-" "_" ] [ "" "" ] template.name;
              hasPathFilter = template.autoInsert ? pathFilter;
              normalizedPathFilter =
                if hasPathFilter then
                  normalizeHomePath (lib.removeSuffix "/**" template.autoInsert.pathFilter)
                else
                  "";
            in
            ''
              vim.api.nvim_create_autocmd("BufNewFile", {
                pattern = "${template.autoInsert.pattern}",
                callback = function(args)
                  local current_file = vim.api.nvim_buf_get_name(args.buf)

                  ${
                    if hasPathFilter then
                      ''
                        local base_path = vim.fn.expand("${normalizedPathFilter}")
                        if current_file:find("^" .. vim.pesc(base_path) .. "/") then
                          vim.schedule(function()
                            vim.api.nvim_set_option_value('filetype', '${template.extension}', { buf = args.buf })
                            local current_buf = vim.api.nvim_get_current_buf()
                            vim.api.nvim_set_current_buf(args.buf)

                            local ok, err = xpcall(function()
                              vim.cmd("Template ${sanitizedName}")
                            end, function(e)
                              return debug.traceback(tostring(e), 2)
                            end)

                            if current_buf ~= args.buf then
                              vim.api.nvim_set_current_buf(current_buf)
                            end
                          end)
                        end
                      ''
                    else
                      ''
                        vim.schedule(function()
                          vim.api.nvim_set_option_value('filetype', '${template.extension}', { buf = args.buf })
                          local current_buf = vim.api.nvim_get_current_buf()
                          vim.api.nvim_set_current_buf(args.buf)

                          local ok, err = xpcall(function()
                            vim.cmd("Template ${sanitizedName}")
                          end, function(e)
                            return debug.traceback(tostring(e), 2)
                          end)

                          if current_buf ~= args.buf then
                            vim.api.nvim_set_current_buf(current_buf)
                          end
                        end)
                      ''
                  }
                end,
              })
            ''
          ) autoInsertTemplates}
        '';
      };

      programs.nixvim = {
        extraPlugins = with pkgs.vimUtils; [
          (buildVimPlugin {
            name = "template-nvim";
            src = pkgs.fetchFromGitHub {
              owner = "nvimdev";
              repo = "template.nvim";
              rev = "308f6f8f0bf98cb7c71855ffa8a3019a5642d1cd";
              hash = "sha256-6yeMCE5GhnICKZqDjphqJ5/W0IuOcEZ157haZGF363Y=";
            };
          })
        ];

        keymaps = templateKeybindings;
      };

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          (
            [
              {
                __unkeyed-1 = "<leader>y";
                group = "Templates";
                icon = "󰷈";
              }
              {
                __unkeyed-1 = "<leader>y<leader>";
                group = "Raw Templates";
                icon = "󰈔";
              }
            ]
            ++ templateWhichKeySpecs
          );
    };
}
