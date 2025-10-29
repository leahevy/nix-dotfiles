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

  group = "desktop";
  input = "linux";
  namespace = "system";

  settings = { };

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
      graphics = {
        opengl = true;
      };
      services = {
        dbus = true;
      };
      desktop-modules = {
        keyd = true;
        gamemode = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      services.libinput.enable = helpers.ifSet self.host.settings.system.touchpad.enabled false;

      console.keyMap = self.host.settings.system.keymap.console;

      environment.systemPackages = with pkgs; [
        gvfs
        gcr
      ];

      security.polkit.enable = true;

      xdg.portal = {
        enable = true;
      };
    };
}
