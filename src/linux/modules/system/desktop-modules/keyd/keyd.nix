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

  group = "desktop-modules";
  input = "linux";
  namespace = "system";

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
            i = oneshot(umlauts_direct)
            shift = layer(diacritics_shift)

            [umlauts]
            a = macro(C-S-u 00e4 enter)
            o = macro(C-S-u 00f6 enter)
            u = macro(C-S-u 00fc enter)
            e = macro(C-S-u 20ac enter)
            shift = layer(umlauts_upper)

            [umlauts_upper]
            a = macro(C-S-u 00c4 enter)
            o = macro(C-S-u 00d6 enter)
            u = macro(C-S-u 00dc enter)

            [umlauts_direct]
            a = ä
            o = ö
            u = ü
            e = €
            shift = layer(umlauts_direct_upper)

            [umlauts_direct_upper]
            a = Ä
            o = Ö
            u = Ü

            [diacritics_shift]
            s = ß
          '';
        };
      };
    };
}
