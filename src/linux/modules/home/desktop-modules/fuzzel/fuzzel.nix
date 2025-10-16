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
  name = "fuzzel";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isModuleEnabled "desktop.niri";

      fuzzelPackage =
        if isNiriEnabled then
          pkgs.fuzzel.overrideAttrs (oldAttrs: {
            postInstall = (oldAttrs.postInstall or "") + ''
              mv $out/bin/fuzzel $out/bin/fuzzel-original

              cat > $out/bin/fuzzel << EOF
              #!/usr/bin/env bash
              set -euo pipefail

              OVERVIEW_WAS_OPEN=0
              if niri msg overview-state | grep -q "Overview is open"; then
                OVERVIEW_WAS_OPEN=1
              fi

              OVERVIEW_TOGGLED=0
              if (( ! OVERVIEW_WAS_OPEN )); then
                if niri msg action toggle-overview; then
                  OVERVIEW_TOGGLED=1
                fi
              fi

              cleanup() {
                if (( OVERVIEW_TOGGLED )); then
                  if niri msg overview-state | grep -q "Overview is open"; then
                    niri msg action toggle-overview
                  fi
                fi
              }
              trap cleanup EXIT

              $out/bin/fuzzel-original "\$@"
              EOF
              chmod +x $out/bin/fuzzel
            '';
          })
        else
          pkgs.fuzzel;
    in
    {
      programs.fuzzel = {
        enable = true;
        package = fuzzelPackage;
        settings = {
          main = {
            terminal = self.settings.terminal;
            layer = "overlay";
            width = 40;
            lines = 15;
            font = lib.mkForce "monospace:size=17";
            prompt = "⇒  ";
            line-height = 25;
            fields = "name,generic,comment,categories,filename,keywords";
            tabs = 4;
            horizontal-pad = 20;
            vertical-pad = 10;
            inner-pad = 10;
            show-actions = "no";
            filter-desktop = "yes";
          };

          colors = {
            background = lib.mkForce "0a0a0fee";
            text = lib.mkForce "ffffffff";
            match = lib.mkForce "ffffff80";
            selection = lib.mkForce "ffffff33";
            selection-text = lib.mkForce "ffffffff";
            selection-match = lib.mkForce "ffffffff";
            border = lib.mkForce "ffffff26";
          };

          border = {
            width = 1;
            radius = 14;
          };
        };
      };

      xdg.desktopEntries."uuctl" = {
        name = "uuctl";
        noDisplay = true;
      };

      home.file.".local/bin/rofi" = {
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          FUZZEL_ARGS=()

          while [[ $# -gt 0 ]]; do
            case $1 in
              -dmenu)
                FUZZEL_ARGS+=("--dmenu")
                ;;
              -format)
                shift
                if [[ "$1" == "i" ]]; then
                  FUZZEL_ARGS+=("--index")
                fi
                ;;
              -matching)
                shift
                case "$1" in
                  fuzzy)
                    FUZZEL_ARGS+=("--match-mode=fuzzy")
                    ;;
                  fzf)
                    FUZZEL_ARGS+=("--match-mode=fzf")
                    ;;
                  exact)
                    FUZZEL_ARGS+=("--match-mode=exact")
                    ;;
                esac
                ;;
              -p)
                shift
                FUZZEL_ARGS+=("--prompt=$1")
                ;;
              -mesg)
                shift
                ;;
              -l|-lines)
                shift
                FUZZEL_ARGS+=("--lines=$1")
                ;;
              *)
                FUZZEL_ARGS+=("$1")
                ;;
            esac
            shift
          done

          exec ${fuzzelPackage}/bin/fuzzel "''${FUZZEL_ARGS[@]}"
        '';
        executable = true;
      };
    };
}
