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
  name = "keyd";

  assertions = [
    {
      assertion = self.user.isModuleEnabled "desktop-modules.keyd";
      message = "Requires linux.desktop-modules.keyd home-manager module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      services.keyd = {
        enable = true;

        keyboards.default = {
          ids = [ "*" ];
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

            [umlauts]
            a = macro(C-S-u 00e4 enter)
            o = macro(C-S-u 00f6 enter)
            u = macro(C-S-u 00fc enter)
            shift = layer(umlauts_upper)

            [umlauts_upper]
            a = macro(C-S-u 00c4 enter)
            o = macro(C-S-u 00d6 enter)
            u = macro(C-S-u 00dc enter)
          '';
        };
      };
    };
}
