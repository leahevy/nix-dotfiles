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
  name = "fish";

  group = "shell";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      shell = {
        go-programs = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages =
        with pkgs;
        [
          fishPlugins.z
          fishPlugins.colored-man-pages
          fishPlugins.fzf
          fishPlugins.pisces
          fishPlugins.fish-you-should-use
          fishPlugins.bang-bang
          fishPlugins.foreign-env
          fishPlugins.nvm
        ]
        ++ (map (pkg: pkgs.fishPlugins.${pkg}) (self.settings.additionalFishPluginsFromPkgs or [ ]));

      home.file."${config.xdg.configHome}/fish-init/00-disable-greeting.fish".text = ''
        set fish_greeting
      '';

      programs = {
        nix-index.enableFishIntegration = true;
        fish = {
          enable = true;

          interactiveShellInit = ''
            set -g fish_color_normal ${
              builtins.substring 1 6 self.theme.colors.terminal.foregrounds.primary.html
            }
            set -g fish_color_param ${
              builtins.substring 1 6 self.theme.colors.terminal.foregrounds.primary.html
            }

            if test -d "${config.xdg.configHome}/fish-init"
              for file in "${config.xdg.configHome}/fish-init/"*.fish
                source "$file"
              end
            end
          ''
          + (
            if self.user.isStandalone then
              ''
                fenv source $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh
              ''
            else
              ""
          );

          functions = {
            gcm = ''
              if test -z "$argv[1]"
                echo "Error: Commit message required"
                return 1
              end

              if git rev-parse --git-dir > /dev/null 2>&1
                set branch (git rev-parse --abbrev-ref HEAD)
                git commit -m "[$branch] $argv[1]"
              else
                echo "Not in a git repository"
                return 1
              end
            '';

            helpme = ''
              if test (count $argv) -lt 2
                echo "Usage: helpme <keyword> <command> [args...]"
                echo "Example: helpme git status"
                return 1
              end

              set keyword $argv[1]
              set cmd_args $argv[2..]

              $cmd_args --help 2>/dev/null | grep -i -C 8 "$keyword" || begin
                $cmd_args -h 2>/dev/null | grep -i -C 8 "$keyword" || begin
                  echo "No help found for keyword '$keyword' in command: $cmd_args"
                  return 1
                end
              end
            '';
          }
          // (self.settings.additionalFishFunctions or { });

          plugins = [
            {
              name = "z";
              src = pkgs.fishPlugins.z.src;
            }
            {
              name = "colored-man-pages";
              src = pkgs.fishPlugins.colored-man-pages.src;
            }
            {
              name = "fzf";
              src = pkgs.fishPlugins.fzf.src;
            }
            {
              name = "pisces";
              src = pkgs.fishPlugins.pisces.src;
            }
            {
              name = "fish-you-should-use";
              src = pkgs.fishPlugins.fish-you-should-use.src;
            }
            {
              name = "bang-bang";
              src = pkgs.fishPlugins.bang-bang.src;
            }
            {
              name = "foreign-env";
              src = pkgs.fishPlugins.foreign-env.src;
            }
            {
              name = "nvm";
              src = pkgs.fishPlugins.nvm.src;
            }
          ]
          ++ (map (pkg: {
            name = pkg;
            src = pkgs.fishPlugins.${pkg}.src;
          }) (self.settings.additionalFishPluginsFromPkgs or [ ]))
          ++ (self.settings.additionalFishPluginsCustom or [ ]);
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/fish"
          ".local/share/fish"
          ".cache/fish"
          ".config/fish-init"
          ".local/share/z"
        ];
      };

      xdg.desktopEntries = lib.optionalAttrs self.isLinux {
        "fish" = {
          name = "fish";
          noDisplay = true;
        };
      };
    };
}
