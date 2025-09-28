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
  name = "niri";

  submodules = {
    linux = {
      desktop = {
        common = true;
      };
      storage = {
        auto-mount = true;
      };
      desktop-modules = {
        wayland = true;
        xwayland-satellite = true;
        greetd = {
          package = pkgs-unstable.niri;
          cmdline = "niri-session";
        };
        programs = true;
      };
    };
  };

  assertions = [
    {
      assertion = self.user.isModuleEnabled "desktop.niri";
      message = "Requires linux.desktop.niri home-manager module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      programs.niri = {
        enable = true;
        package = pkgs-unstable.niri;
      };

      services.displayManager.sessionPackages = lib.mkForce [ ];

      environment.systemPackages = with pkgs; [
        wayland-utils
        wl-clipboard
        wlr-randr
        grim
        slurp
        wf-recorder
      ];

      security.pam.services.swaylock = { };

      xdg.portal = {
        wlr.enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
          xdg-desktop-portal-gnome
          kdePackages.xdg-desktop-portal-kde
        ];
      };
    };
}
