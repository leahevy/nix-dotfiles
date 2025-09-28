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
  name = "xserver";

  configuration =
    context@{ config, options, ... }:
    {
      services.xserver = {
        enable = true;
        xkb = {
          layout = self.host.settings.system.keymap.x11.layout;
          variant = self.host.settings.system.keymap.x11.variant;
          options = self.host.settings.system.keymap.x11.options;
        };
      };
    };
}
