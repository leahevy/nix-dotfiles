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
  name = "common";

  defaults = { };

  assertions = [
    {
      assertion = self.user.isModuleEnabled "desktop.common";
      message = "Requires linux.desktop.common home-manager module to be enabled!";
    }
  ];

  submodules = {
    linux = {
      power = {
        modes = true;
      };
      sound = {
        pipewire = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      services.libinput.enable = helpers.ifSet self.host.settings.system.touchpad.enabled false;

      console.keyMap = self.host.settings.system.keymap.console;

      services.xserver.xkb = {
        layout = self.host.settings.system.keymap.x11.layout;
        variant = self.host.settings.system.keymap.x11.variant;
      };

    };
}
