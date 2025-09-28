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
  name = "user-dirs";

  defaults = {
    download = "downloads";
    documents = "documents";
    desktop = "desktop";
    pictures = "pictures";
    videos = "videos";
    music = "music";
    publicShare = "public";
    templates = "templates";
  };

  configuration =
    context@{ config, options, ... }:
    {
      config = lib.mkIf self.isLinux (
        if !(self.linux.isModuleEnabled "storage.luks-data-drive") then
          {
            home.file =
              (lib.mapAttrs' (
                xdgName: dirName:
                lib.nameValuePair dirName {
                  source = helpers.symlinkToHomeDirPath config ".data/${dirName}";
                }
              ) self.settings)
              // {
                "data".source = helpers.symlinkToHomeDirPath config ".data/data";
                "develop".source = helpers.symlinkToHomeDirPath config ".data/develop";
              };

            xdg.userDirs = {
              enable = true;
            }
            // lib.mapAttrs (xdgName: dirName: "${config.home.homeDirectory}/${dirName}") self.settings;

            home.persistence."${self.persist}" = {
              directories = (map (dir: ".data/${dir}") (lib.attrValues self.settings)) ++ [
                ".data/data"
                ".data/develop"
              ];
            };
          }
        else
          let
            mountPoint = (self.linux.host.getModuleConfig "storage.luks-data-drive").mountpoint;
          in
          {
            home.file =
              (lib.mapAttrs' (
                xdgName: dirName:
                lib.nameValuePair dirName {
                  source = helpers.symlink config "${mountPoint}/${self.host.hostname}/${self.user.home}/${dirName}";
                }
              ) self.settings)
              // {
                "data".source = helpers.symlink config "${mountPoint}/${self.host.hostname}/${self.user.home}/data";
                "develop".source =
                  helpers.symlink config "${mountPoint}/${self.host.hostname}/${self.user.home}/develop";
              };

            xdg.userDirs = {
              enable = true;
            }
            // lib.mapAttrs (xdgName: dirName: "${config.home.homeDirectory}/${dirName}") self.settings;
          }
      );
    };
}
