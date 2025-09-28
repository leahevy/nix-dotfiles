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
  name = "zoom";

  unfree = [
    "zoom"
  ];

  configuration =
    context@{ config, options, ... }:
    let
      desktopPreference = self.user.settings.desktopPreference;
      isKDE = desktopPreference == "kde";
      isGnome = desktopPreference == "gnome";

      customPkgs =
        if self.isLinux then
          (self.pkgs {
            overlays = [
              (final: prev: {
                zoom-us = prev.zoom-us.override {
                  xdgDesktopPortalSupport = true;
                  plasma6XdgDesktopPortalSupport = isKDE;
                  gnomeXdgDesktopPortalSupport = isGnome;
                };
              })
            ];
          })
        else
          pkgs;
    in
    {
      home.packages = [
        customPkgs.zoom-us
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".cache/zoom"
          ".zoom"
        ];
        files = [
          ".config/zoom.conf"
          ".config/zoomus.conf"
        ];
      };
    };
}
