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

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    templates = [ ];

    baseTemplates = [
      {
        name = "nix-module";
        shortcut = "n";
        extension = "nix";
        icon = "󱃗";
        autoInsert = {
          pattern = "*.nix";
          pathFilter = [
            "~/.config/nx/nxcore/src"
            "~/.config/nx/nxconfig/modules"
            "~/.config/nx/nxconfig/profiles"
          ];
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

          local function get_current_file_path()
            local current = vim.fn.expand('%:.:r')
            local absolute = vim.fn.resolve(vim.fn.fnamemodify(current, ":p:r"))
            local home_dir = vim.fn.expand("~")
            return absolute:gsub("^" .. vim.pesc(home_dir), "~")
          end

          local function extract_path_components()
            local path = get_current_file_path()
            local parts = vim.split(path, '/')

            local modules_index = nil
            for i, part in ipairs(parts) do
              if part == "modules" then
                modules_index = i
                break
              end
            end

            if not modules_index then
              error("Module file not in correct location - missing 'modules' in path")
            end

            local input_name = "unknown"

            for i = 1, modules_index - 1 do
              if parts[i] == "nxcore" and i + 1 < modules_index and parts[i + 1] == "src" and i + 2 < modules_index then
                input_name = parts[i + 2]
                break
              elseif parts[i] == "nxconfig" then
                if i + 1 < modules_index and parts[i + 1] == "profiles" then
                  input_name = "profile"
                elseif i + 1 == modules_index then
                  input_name = "config"
                end
                break
              end
            end

            if modules_index + 3 > #parts then
              error("Invalid module path structure - expected modules/NAMESPACE/GROUP/MODULE/")
            end

            local namespace = parts[modules_index + 1]
            local group = parts[modules_index + 2]

            return {
              input = input_name,
              namespace = namespace,
              group = group,
            }
          end

          function extract_input()
            local ok, result = pcall(extract_path_components)
            return ok and result.input or "INVALID_PATH"
          end

          function extract_namespace()
            local ok, result = pcall(extract_path_components)
            return ok and result.namespace or "INVALID_PATH"
          end

          function extract_group()
            local ok, result = pcall(extract_path_components)
            return ok and result.group or "INVALID_PATH"
          end

          ${lib.concatMapStringsSep "\n" (
            template:
            let
              sanitizedName = lib.replaceStrings [ "-" "_" ] [ "" "" ] template.name;
              hasPathFilter = template.autoInsert ? pathFilter;
              normalizedPathFilters =
                if hasPathFilter then
                  map (path: normalizeHomePath (lib.removeSuffix "/**" path)) template.autoInsert.pathFilter
                else
                  [ ];
            in
            ''
              vim.api.nvim_create_autocmd("BufNewFile", {
                pattern = "${template.autoInsert.pattern}",
                callback = function(args)
                  local current_file = vim.api.nvim_buf_get_name(args.buf)
                  local absolute_file = vim.fn.resolve(vim.fn.fnamemodify(current_file, ":p"))
                  local home_dir = vim.fn.expand("~")
                  local tilde_file = absolute_file:gsub("^" .. vim.pesc(home_dir), "~")

                  ${
                    if hasPathFilter then
                      ''
                        local matches_path = false
                        ${lib.concatMapStringsSep "\n                        " (path: ''
                          local base_path = vim.fn.expand("${path}")
                          if current_file:find("^" .. vim.pesc(base_path) .. "/") or
                             absolute_file:find("^" .. vim.pesc(base_path) .. "/") or
                             tilde_file:find("^" .. vim.pesc("${path}") .. "/") then
                            matches_path = true
                          end
                        '') normalizedPathFilters}
                        if matches_path then
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
