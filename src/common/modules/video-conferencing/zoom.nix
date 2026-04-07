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

  group = "video-conferencing";
  input = "common";

  unfree = [
    "zoom"
  ];

  on = {
    home =
      config:
      let
        desktopPreference = self.user.settings.desktopPreference;
        isKDE = desktopPreference == "kde";
        isGnome = desktopPreference == "gnome";
      in
      {
        home.packages = [
          (
            if self.isLinux then
              pkgs.zoom-us.override {
                xdgDesktopPortalSupport = true;
                plasma6XdgDesktopPortalSupport = isKDE;
                gnomeXdgDesktopPortalSupport = isGnome;
              }
            else
              pkgs.zoom-us
          )
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
  };
}
