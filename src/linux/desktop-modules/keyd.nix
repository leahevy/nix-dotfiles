args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  buildConf =
    { deviceIdsToIgnore, enableDevices }:
    let
      ignoreIds = map (id: "-${id}") deviceIdsToIgnore;
    in
    {
      default = {
        ids = [ "*" ] ++ ignoreIds;
        settings = {
          main = {
            capslock = "overload(control, esc)";
            rightalt = "layer(diacritics)";
          };
          meta = {
            c = "C-c";
            v = "C-v";
            x = "C-x";
          };
          alt = {
            esc = "`";
          };
          shift = {
            esc = "~";
          };
        };
        extraConfig = ''
          [diacritics]
          s = macro(C-S-u 00df enter)
          u = oneshot(umlauts)
          i = oneshot(umlauts_direct)
          shift = layer(diacritics_shift)

          [umlauts]
          a = macro(C-S-u 00e4 enter)
          o = macro(C-S-u 00f6 enter)
          u = macro(C-S-u 00fc enter)
          e = macro(C-S-u 20ac enter)
          - = macro(C-S-u 2014 enter)
          shift = layer(umlauts_upper)

          [umlauts_upper]
          a = macro(C-S-u 00c4 enter)
          o = macro(C-S-u 00d6 enter)
          u = macro(C-S-u 00dc enter)
          - = macro(C-S-u 2013 enter)

          [umlauts_direct]
          a = ä
          o = ö
          u = ü
          e = €
          - = —
          shift = layer(umlauts_direct_upper)

          [umlauts_direct_upper]
          a = Ä
          o = Ö
          u = Ü
          - = –

          [diacritics_shift]
          s = ß
        '';
      };
    }
    // lib.optionalAttrs enableDevices.kensingtonExpertMouse {
      kensingtonExpertMouse = {
        ids = [ "m:047d:8018:b91d4c8c" ];
        settings.main.mouse1 = "leftmeta";
      };
    };

  renderKeydConf =
    {
      ids,
      settings,
      extraConfig ? "",
    }:
    "[ids]\n"
    + lib.concatStringsSep "\n" ids
    + "\n\n"
    + lib.concatStringsSep "\n\n" (
      lib.mapAttrsToList (
        name: attrs:
        "[${name}]\n" + lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${v}") attrs)
      ) settings
    )
    + lib.optionalString (extraConfig != "") ("\n\n" + extraConfig);
in
{
  name = "keyd";

  group = "desktop-modules";
  input = "linux";

  disableOnVirtual = true;

  options = {
    deviceIdsToIgnore = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Device ids excluded from the default keyd keyboard match.";
    };
    enableDevices = lib.mkOption {
      type = lib.types.submodule {
        options = {
          kensingtonExpertMouse = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Remap the Kensington Expert Wireless mouse side button to Super.";
          };
        };
      };
      default = { };
      description = "Per device opt-in toggles for extra keyd keyboard entries.";
    };
  };

  module = {
    linux.home = config: {
      home.packages = with pkgs; [
        keyd
      ];

      home.file.".XCompose".source = "${helpers.packageFile args pkgs.keyd "share/keyd/keyd.compose"}";

      home.sessionVariables = {
        GTK_IM_MODULE = "xim";
        QT_IM_MODULE = "xim";
        XMODIFIERS = "@im=none";
      };
    };

    linux.enabled =
      config:
      let
        deviceIdsToIgnore = config.nx.linux."desktop-modules".keyd.deviceIdsToIgnore;
        enableDevices = config.nx.linux."desktop-modules".keyd.enableDevices;
        keyboards = buildConf { inherit deviceIdsToIgnore enableDevices; };
        confsDir = pkgs.linkFarm "keyd-confs" (
          lib.mapAttrsToList (name: kbd: {
            name = "${name}.conf";
            path = pkgs.writeText "${name}.conf" (renderKeydConf kbd);
          }) keyboards
        );
        syncScript = pkgs.writeShellScript "keyd-sync" ''
          #!/usr/bin/env bash
          set -euo pipefail

          WHITE='\033[1;37m'
          GREEN='\033[1;32m'
          RED='\033[1;31m'
          RESET='\033[0m'

          if [[ $EUID -eq 0 ]]; then
            echo -e "''${RED}Do not run as root!''${RESET}" >&2
            exit 1
          fi

          echo -e "''${WHITE}Writing keyd config...''${RESET}"
          sudo mkdir -p /etc/keyd

          for f in /etc/keyd/*.conf; do
            [[ -e "''${f}" ]] || continue
            if [[ ! -e "${confsDir}/$(basename "''${f}")" ]]; then
              sudo rm "''${f}"
            fi
          done

          for f in "${confsDir}"/*.conf; do
            sudo install -m 644 "''${f}" "/etc/keyd/$(basename "''${f}")"
          done

          echo -e "''${WHITE}Reloading keyd service...''${RESET}"
          if systemctl is-active --quiet keyd 2>/dev/null; then
            sudo systemctl restart keyd
          else
            sudo systemctl enable --now keyd
          fi

          echo -e "''${GREEN}keyd config applied.''${RESET}"
        '';
      in
      {
        nx.apt.packages = [ "keyd" ];
        nx.apt.postInstallScripts = [ syncScript ];
      };

    system =
      {
        config,
        deviceIdsToIgnore,
        enableDevices,
        ...
      }:
      let
        keyboards = buildConf { inherit deviceIdsToIgnore enableDevices; };
      in
      {
        services.keyd = {
          enable = true;
          keyboards = lib.mapAttrs (
            _: kbd:
            {
              inherit (kbd) ids settings;
            }
            // lib.optionalAttrs (kbd ? extraConfig) { inherit (kbd) extraConfig; }
          ) keyboards;
        };

        systemd.services.keyd = {
          unitConfig = {
            StartLimitIntervalSec = "60s";
            StartLimitBurst = 5;
          };
          serviceConfig = {
            RestartSec = "5s";
          };
        };
      };
  };
}
