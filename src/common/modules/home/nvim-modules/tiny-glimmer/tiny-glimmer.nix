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
  name = "tiny-glimmer";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enabled = true;
    disableWarnings = true;
    refreshIntervalMs = 8;
    transparencyColor = null;

    excludeFiletypes = [
      "dashboard"
      "alpha"
      "toggleterm"
      "terminal"
      "NvimTree"
      "netrw"
      "telescope"
      "help"
      "lspinfo"
      "checkhealth"
      "man"
      "gitcommit"
      "gitrebase"
      "fugitive"
      "startify"
      "Codewindow"
      "qf"
      "prompt"
      "nofile"
      "nowrite"
      "notify"
      "yazi"
      ""
    ];

    yank = "fade";
    paste = "reverse_fade";
    search = "pulse";
    undo = "fade";
    redo = "fade";

    animations = {
      fade = {
        duration = 500;
        charsForMaxDuration = 10;
        easing = "outQuad";
        fromColor = "#89b4fa";
        toColor = "#1e1e2e";
      };

      reverse_fade = {
        duration = 500;
        charsForMaxDuration = 10;
        easing = "outBack";
        fromColor = "#a6e3a1";
        toColor = "#1e1e2e";
      };

      pulse = {
        duration = 600;
        charsForMaxDuration = 15;
        pulseCount = 2;
        intensity = 1.2;
        fromColor = "#006600";
        toColor = "#1e1e2e";
      };

      bounce = {
        duration = 500;
        charsForMaxDuration = 20;
        oscillationCount = 1;
        fromColor = "#f38ba8";
        toColor = "#1e1e2e";
      };

      rainbow = {
        duration = 600;
        charsForMaxDuration = 20;
      };

      left_to_right = {
        duration = 350;
        charsForMaxDuration = 25;
        lingeringTime = 50;
        fromColor = "#cba6f7";
        toColor = "#1e1e2e";
      };
    };

    pulsar = {
      animation = "pulse";
      onEvents = [
        "CursorMoved"
        "CursorMovedI"
        "InsertEnter"
        "InsertLeave"
        "ModeChanged"
        "CmdlineEnter"
        "CmdlineLeave"
        "WinEnter"
        "WinLeave"
        "BufEnter"
        "BufLeave"
        "FocusGained"
        "FocusLost"
        "SearchWrapped"
      ];
    };

    github = {
      owner = "rachartier";
      repo = "tiny-glimmer.nvim";
      rev = "d42902711d6f7708661b4badb7095efed610146a";
      hash = "sha256-oyklfcxQaRQpOGaRNwWbpbrnxTZepSEfWfucCZAczkU=";
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      configToLuaProps =
        config:
        let
          convertKey =
            key:
            if key == "charsForMaxDuration" then
              "chars_for_max_duration"
            else if key == "fromColor" then
              "from_color"
            else if key == "toColor" then
              "to_color"
            else if key == "pulseCount" then
              "pulse_count"
            else if key == "oscillationCount" then
              "oscillation_count"
            else if key == "lingeringTime" then
              "lingering_time"
            else
              key;

          minDuration = if config ? duration then toString (config.duration * 80 / 100) else null;

          configProps = lib.mapAttrsToList (
            key: value:
            let
              luaKey = convertKey key;
            in
            if key == "duration" then
              null
            else if lib.isString value then
              "${luaKey} = \"${value}\""
            else
              "${luaKey} = ${toString value}"
          ) config;

          durationProps =
            if config ? duration then
              [
                "max_duration = ${toString config.duration}"
                "min_duration = ${minDuration}"
              ]
            else
              [ ];

          allProps = durationProps ++ (lib.filter (x: x != null) configProps);
        in
        lib.concatStringsSep ",\n              " allProps;

      generateAnimation = name: config: ''
        ${name} = {
                    ${configToLuaProps config}
                  }'';

      allAnimations = lib.concatStringsSep ",\n            " (
        lib.mapAttrsToList generateAnimation self.settings.animations
      );

      pulsarAnimConfig = self.settings.animations.${self.settings.pulsar.animation};
      pulsarSettings = configToLuaProps pulsarAnimConfig;
    in
    {
      programs.nixvim = {
        extraPlugins = with pkgs.vimUtils; [
          (buildVimPlugin {
            name = "tiny-glimmer-nvim";
            src = pkgs.fetchFromGitHub {
              owner = self.settings.github.owner;
              repo = self.settings.github.repo;
              rev = self.settings.github.rev;
              hash = self.settings.github.hash;
            };
          })
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>r";
            action = "<cmd>lua _G.toggle_tiny_glimmer()<CR>";
            options = {
              desc = "Toggle animations";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>r";
            desc = "Toggle animations";
            icon = "✨";
          }
        ];
      };

      home.file.".config/nvim-init/50-tiny-glimmer.lua".text = ''
        local tiny_glimmer = require('tiny-glimmer')

        _G.tiny_glimmer_enabled = ${if self.settings.enabled then "true" else "false"}

        local excluded_filetypes = {
          ${lib.concatMapStringsSep ", " (ft: "'${ft}'") self.settings.excludeFiletypes}
        }

        local function should_enable_animations()
          local ft = vim.bo.filetype
          local buftype = vim.bo.buftype

          for _, excluded_ft in ipairs(excluded_filetypes) do
            if ft == excluded_ft then
              return false
            end
          end

          if buftype ~= "" and buftype ~= "nofile" then
            return false
          end

          return _G.tiny_glimmer_enabled
        end

        function _G.toggle_tiny_glimmer()
          _G.tiny_glimmer_enabled = not _G.tiny_glimmer_enabled

          if _G.tiny_glimmer_enabled then
            tiny_glimmer.enable()
            vim.notify("Tiny Glimmer animations enabled", vim.log.levels.INFO)
          else
            tiny_glimmer.disable()
            vim.notify("Tiny Glimmer animations disabled", vim.log.levels.INFO)
          end
        end

        tiny_glimmer.setup({
          enabled = true,
          disable_warnings = ${if self.settings.disableWarnings then "true" else "false"},
          refresh_interval_ms = ${toString self.settings.refreshIntervalMs},
          ${lib.optionalString (
            self.settings.transparencyColor != null
          ) "transparency_color = '${self.settings.transparencyColor}',"}

          overwrite = {
            auto_map = true,

            ${lib.optionalString (self.settings.yank != null) ''
              yank = {
                enabled = true,
                default_animation = "${self.settings.yank}",
              },''}

            ${lib.optionalString (self.settings.paste != null) ''
              paste = {
                enabled = true,
                default_animation = "${self.settings.paste}",
                paste_mapping = "p",
                Paste_mapping = "P",
              },''}

            ${lib.optionalString (self.settings.search != null) ''
              search = {
                enabled = true,
                default_animation = "${self.settings.search}",
                next_mapping = "n",
                prev_mapping = "N",
              },''}

            ${lib.optionalString (self.settings.undo != null) ''
              undo = {
                enabled = true,
                default_animation = "${self.settings.undo}",
                undo_mapping = "u",
              },''}

            ${lib.optionalString (self.settings.redo != null) ''
              redo = {
                enabled = true,
                default_animation = "${self.settings.redo}",
                redo_mapping = "<C-r>",
              },''}
          },

          presets = {
            pulsar = {
              enabled = ${if self.settings.pulsar.animation != null then "true" else "false"},
              on_events = { ${
                lib.concatMapStringsSep ", " (event: "\"${event}\"") self.settings.pulsar.onEvents
              } },
              default_animation = {
                name = "${self.settings.pulsar.animation}",
                settings = {
                  ${pulsarSettings}
                }
              }
            }
          },

          animations = {
            ${allAnimations}
          }
        })

        if not _G.tiny_glimmer_enabled then
          tiny_glimmer.disable()
        end

        vim.api.nvim_create_autocmd({"BufEnter", "FileType"}, {
          callback = function()
            if not should_enable_animations() then
              tiny_glimmer.disable()
            elseif _G.tiny_glimmer_enabled then
              tiny_glimmer.enable()
            end
          end
        })

        vim.api.nvim_create_autocmd("VimEnter", {
          once = true,
          callback = function()
            vim.defer_fn(function()
              if should_enable_animations() then
                tiny_glimmer.enable()
              else
                tiny_glimmer.disable()
              end
            end, 100)
          end
        })
      '';
    };
}
