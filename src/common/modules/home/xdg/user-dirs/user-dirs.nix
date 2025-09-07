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
  userDirs = {
    download = "downloads";
    documents = "documents";
    desktop = "desktop";
    pictures = "pictures";
    videos = "videos";
    music = "music";
    publicShare = "public";
    templates = "templates";
  };
in
{
  configuration =
    context@{ config, options, ... }:
    {
      config = lib.mkIf self.isLinux {
        home.file = lib.mapAttrs' (
          xdgName: dirName:
          lib.nameValuePair dirName {
            source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.data/${dirName}";
          }
        ) userDirs;

        xdg.userDirs = {
          enable = true;
        }
        // lib.mapAttrs (xdgName: dirName: "${config.home.homeDirectory}/${dirName}") userDirs;

        home.persistence."${self.persist}" = {
          directories = map (dir: ".data/${dir}") (lib.attrValues userDirs);
        };
      };
    };
}
