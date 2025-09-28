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
  name = "swaybg";

  defaults = {
    output = "*";
    mode = "fit";
    backgroundColor = "#000000";
  };

  configuration =
    context@{ config, options, ... }:
    let
      getStylixWallpaper =
        let
          stylixConfig =
            if self.user.isStandalone then
              self.common.getModuleConfig "style.stylix"
            else
              self.common.host.getModuleConfig "style.stylix";

          getStylixFile =
            fileName:
            if self.user.isStandalone then
              helpers.getInputFilePath (helpers.resolveInputFromInput "common") "modules/home/style/stylix/files/${fileName}"
            else
              helpers.getInputFilePath (helpers.resolveInputFromInput "common") "modules/system/style/stylix/files/${fileName}";
        in
        if (stylixConfig.wallpaper.config or null) != null then
          self.config.filesPath stylixConfig.wallpaper.config
        else if
          (stylixConfig.wallpaper.url or null) != null && (stylixConfig.wallpaper.url.url or null) != null
        then
          pkgs.fetchurl {
            url = stylixConfig.wallpaper.url.url;
            hash = stylixConfig.wallpaper.url.hash;
          }
        else if (stylixConfig.wallpaper.local or null) != null then
          stylixConfig.wallpaper.local
        else
          getStylixFile "wallpaper.jpg";
    in
    {
      home.packages = [ pkgs.swaybg ];

      systemd.user.services.nx-swaybg = {
        Unit = {
          Description = "Wayland wallpaper daemon";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${pkgs.swaybg}/bin/swaybg -o ${self.settings.output} -i ${getStylixWallpaper} -m ${self.settings.mode} -c ${self.settings.backgroundColor}";
          Restart = "on-failure";
          RestartSec = "1";
          Type = "simple";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
}
