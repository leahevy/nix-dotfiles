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
let
  host = self.host;
  ifSet = helpers.ifSet;
in
{
  configuration =
    context@{ config, options, ... }:
    {
      services.xserver.enable = ifSet host.settings.system.desktop.gnome.enabled false;

      services.xserver.displayManager.gdm.enable = ifSet host.settings.system.desktop.gnome.enabled false;
      services.xserver.desktopManager.gnome.enable =
        ifSet host.settings.system.desktop.gnome.enabled false;

      services.xserver.xkb = {
        layout = host.settings.system.keymap.x11.layout;
        variant = host.settings.system.keymap.x11.variant;
      };

      services.libinput.enable = ifSet host.settings.system.touchpad.enabled false;

      console.keyMap = host.settings.system.keymap.console;

      services.xserver.desktopManager.gnome.extraGSettingsOverrides = ''
        [org.gnome.shell]
        welcome-dialog-last-shown-version='999.999'
      '';

      services.xserver.desktopManager.plasma5.excludePackages = with pkgs.libsForQt5; [
        plasma-welcome
      ];
    };
}
