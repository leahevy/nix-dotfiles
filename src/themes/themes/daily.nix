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
  wallpaperInfo = self.inputs.nix-season-wallpaper.resolveDailyWallpaper self.inputs.newestFlake.self;
in
{
  name = "daily";
  group = "themes";
  input = "themes";

  submodules = {
    themes.themes.${wallpaperInfo.metadata.style} = true;
  };

  module = {
    enabled =
      config:
      let
        isWidescreen = helpers.resolveFromHostOrUser config [ "displays" "mainIsWidescreen" ] true;
        wallpaper = if isWidescreen then wallpaperInfo.widescreen else wallpaperInfo.normal;
      in
      {
        nx.common.style.stylix.wallpaper.source.localPath = lib.mkForce wallpaper.path;
        nx.common.style.stylix.wallpaper.extension = lib.mkForce wallpaper.extension;
      };
  };
}
