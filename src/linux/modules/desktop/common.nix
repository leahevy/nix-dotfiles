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

  submodules = {
    linux = {
      desktop-modules = {
        keyd = true;
        gamemode = true;
      };
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
    };
  };

  on = {
    linux.home = config: {
      home = {
        sessionVariables = {
          QT_QPA_PLATFORMTHEME = lib.mkForce "gtk3";
          QT_QPA_PLATFORMTHEME_QT6 = lib.mkForce "gtk3";
        };
      };
    };

    linux.system = config: {
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
  };
}
