args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  version = "1.5.2";
  rev = "4ec42c035efe3cf2123e0c732dca2c7b4c028ae4";
  icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/aliacollins/EveLens/${rev}/EveLensLogo.ico";
    sha256 = "0n8j50h3mbvcils50i8xl2wz54b3yxnysnw7vkxblvqfk29m2l0m";
  };
  iconPng =
    pkgs.runCommand "evelens-icon.png"
      {
        nativeBuildInputs = [ pkgs.imagemagick ];
      }
      ''
        convert '${icon}[0]' -resize 256x256 $out
      '';
  src = pkgs.fetchurl {
    url = "https://github.com/aliacollins/EveLens/releases/download/v${version}/EveLens-stable-linux-x86_64.AppImage";
    sha256 = "0rvn3lffx2m22inn9yf4yvahpxv1kprvld8x30j9sjvhiz7y2dl4";
  };
  appimage = pkgs.appimageTools.wrapType2 {
    pname = "eve-lens";
    inherit version src;
    extraPkgs = pkgs: [
      pkgs.icu
      pkgs.libice
    ];
  };
  eveLens = pkgs.writeShellScriptBin "eve-lens" ''
    exec ${appimage}/bin/eve-lens "$@"
  '';
in
{
  name = "eve-lens";
  description = "EVE Online character monitor and skill planner";

  group = "games";
  input = "linux";

  module = {
    home = config: {
      home.packages = [ eveLens ];

      xdg.dataFile."icons/hicolor/256x256/apps/evelens.png".source = iconPng;
      xdg.dataFile."applications/evelens.desktop".text = ''
        [Desktop Entry]
        Hidden=true
      '';

      xdg.desktopEntries."eve-lens" = {
        name = "EveLens";
        exec = "${eveLens}/bin/eve-lens";
        icon = "evelens";
        terminal = false;
        categories = [
          "Game"
          "Utility"
        ];
        settings.StartupWMClass = "EveLens";
      };

      home.persistence."${self.persist}" = {
        directories = [ ".config/EveLens" ];
      };
    };
  };
}
