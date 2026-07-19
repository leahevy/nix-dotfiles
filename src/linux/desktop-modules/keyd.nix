args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
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

    system =
      {
        config,
        deviceIdsToIgnore,
        enableDevices,
        ...
      }:
      let
        ignoreIds = map (id: "-${id}") deviceIdsToIgnore;
        keyboardIds = [ "*" ] ++ ignoreIds;
      in
      {
        services.keyd =
          lib.recursiveUpdate
            {
              enable = true;

              keyboards.default = {
                ids = keyboardIds;
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
            (
              lib.optionalAttrs enableDevices.kensingtonExpertMouse {
                keyboards.kensingtonExpertMouse = {
                  ids = [ "m:047d:8018:b91d4c8c" ];
                  settings.main.mouse1 = "leftmeta";
                };
              }
            );

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
