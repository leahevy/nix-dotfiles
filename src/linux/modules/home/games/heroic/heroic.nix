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
  name = "heroic";

  group = "games";
  input = "linux";
  namespace = "home";

  submodules = {
    linux = {
      games = {
        utils = true;
      };
      graphics = {
        opengl = true;
      };
    };
  };

  settings = {
    withWayland = false;
    games = {
      stardewValley = false;
      torchlightII = false;
    };
    additionalGameStateDirs = [ ];
    withUmu = true;
    portsPerGame = {
      torchlightII = {
        tcp = [ 4549 ];
        udp = [
          4171
          4175
          4179
          4549
        ];
      };
    };
    persistentOpenPortsForGames = {
      torchlightII = false;
    };
    additionalTCPPortsToOpen = [ ];
    additionalUDPPortsToOpen = [ ];
    additionalFirewallScripts = {
      steam = {
        tcp = [
          27036
          27037
        ]
        ++ lib.map (n: 27015 + n) (lib.range 0 15);
        udp = [
          4380
        ]
        ++ lib.map (n: 27000 + n) (lib.range 0 31);
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      withWayland = self.settings.withWayland;

      enabledGamePorts = lib.filterAttrs (
        gameName: gameConfig:
        let
          isGameEnabled = self.settings.games.${gameName} or false;
          isPersistent = self.settings.persistentOpenPortsForGames.${gameName} or false;
          hasAnyPorts = (gameConfig.tcp or [ ] != [ ]) || (gameConfig.udp or [ ] != [ ]);
        in
        isGameEnabled && !isPersistent && hasAnyPorts
      ) self.settings.portsPerGame;

      additionalScriptPorts = lib.filterAttrs (
        scriptName: scriptConfig: (scriptConfig.tcp or [ ] != [ ]) || (scriptConfig.udp or [ ] != [ ])
      ) self.settings.additionalFirewallScripts;

      allFirewallTargets = enabledGamePorts // additionalScriptPorts;
      availableTargets = lib.attrNames allFirewallTargets;

      heroicFirewallScript =
        lib.optional (self.isModuleEnabled "networking.firewall" && allFirewallTargets != { })
          (
            pkgs.stdenv.mkDerivation {
              name = "heroic-open-firewall";
              buildCommand = ''
                mkdir -p $out/bin $out/share/bash-completion/completions $out/share/zsh/site-functions $out/share/fish/vendor_completions.d

                cat > $out/bin/heroic-open-firewall << 'SCRIPT_EOF'
                #!/usr/bin/env bash
                set -euo pipefail

                if [ $# -eq 0 ]; then
                  echo "Usage: heroic-open-firewall TARGET [TARGET ...]"
                  echo "Available targets: ${lib.concatStringsSep " " availableTargets}"
                  exit 1
                fi

                for target in "$@"; do
                  case "$target" in
                    ${lib.concatMapStringsSep "\n                " (target: "${target}) ;;") availableTargets}
                    *)
                      echo "Error: Unknown target '$target'"
                      echo "Available targets: ${lib.concatStringsSep " " availableTargets}"
                      exit 1
                      ;;
                  esac
                done

                ALL_PORTS=()

                ${lib.concatMapStringsSep "\n            " (
                  target:
                  let
                    config = allFirewallTargets.${target};
                    tcpPortSpecs = map (port: "${toString port}/tcp") (config.tcp or [ ]);
                    udpPortSpecs = map (port: "${toString port}/udp") (config.udp or [ ]);
                    allPortSpecs = tcpPortSpecs ++ udpPortSpecs;
                  in
                  ''
                    if [[ " $* " == *" ${target} "* ]]; then
                      echo "Adding ports for ${target}..."
                      ALL_PORTS+=(${lib.concatStringsSep " " allPortSpecs})
                    fi''
                ) availableTargets}

                if [ ''${#ALL_PORTS[@]} -eq 0 ]; then
                  echo "No ports to open for selected targets"
                  exit 1
                fi

                echo "Opening firewall ports for: $*"
                echo "Total ports: ''${ALL_PORTS[*]}"

                exec firewall-open-script --with-cleanup "''${ALL_PORTS[@]}"
                SCRIPT_EOF

                chmod +x $out/bin/heroic-open-firewall

                cat > $out/share/bash-completion/completions/heroic-open-firewall << 'BASH_EOF'
                _heroic_open_firewall() {
                  local cur targets
                  cur="''${COMP_WORDS[COMP_CWORD]}"
                  targets="${lib.concatStringsSep " " availableTargets}"
                  COMPREPLY=($(compgen -W "$targets" -- "$cur"))
                  return 0
                }
                complete -F _heroic_open_firewall -o nospace heroic-open-firewall
                BASH_EOF

                cat > $out/share/zsh/site-functions/_heroic-open-firewall << 'ZSH_EOF'
                #compdef heroic-open-firewall
                _heroic_open_firewall() {
                  _arguments -S '*:targets:(${lib.concatStringsSep " " availableTargets})'
                }
                _heroic_open_firewall "$@"
                ZSH_EOF

                cat > $out/share/fish/vendor_completions.d/heroic-open-firewall.fish << 'FISH_EOF'
                complete -c heroic-open-firewall -f -a "${lib.concatStringsSep " " availableTargets}"
                FISH_EOF
              '';
            }
          );
    in
    {
      home.packages =
        with pkgs-unstable;
        [
          heroic
          steam-run
          mangohud
          protonup
          protontricks
          lutris
          bottles
          winetricks
          (if withWayland then wineWowPackages.waylandFull else wineWowPackages.stable)
        ]
        ++ heroicFirewallScript;

      home.persistence."${self.persist}" = {
        directories = [
          ".config/heroic"
          ".local/share/comet"
          ".local/state/Heroic/logs"
          ".config/unity3d"
          ".local/share/GOG.com"
          ".local/share/lutris"
          ".cache/lutris"
          ".wine"
        ]
        ++ lib.optionals self.settings.games.stardewValley [
          ".config/StardewValley"
        ]
        ++ lib.optionals self.settings.games.torchlightII [
          ".local/share/Runic Games/Torchlight 2"
        ]
        ++ lib.optionals self.settings.withUmu [
          ".local/share/umu"
          ".cache/umu"
          ".cache/umu-protonfixes"
        ]
        ++ self.settings.additionalGameStateDirs;
      };
    };
}
