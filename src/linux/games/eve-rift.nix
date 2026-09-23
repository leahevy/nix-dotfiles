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
  version = "5.33.0";
  rev = "daf5170c9f1cc450a57d6296fec659e1de173904";
  icon = pkgs.fetchurl {
    url = "https://gitlab.com/rift-intel-fusion-tool/rift-intel-fusion-tool/-/raw/${rev}/icon/Icon-256.png";
    hash = "sha256-/AWm9ATiWG3tTFaj0ceOuWu85sf2yHYX541qBH5r+m0=";
  };
  src = pkgs.fetchurl {
    url = "https://riftforeve.online/download/appimage/RIFT_Intel_Fusion_Tool-${version}.AppImage";
    hash = "sha256-1PpUCWSoNBaC9U0V8M0FK1HLrgpH9PWeqbZ0cbuPGDc=";
  };
  appimage = pkgs.appimageTools.wrapType2 {
    pname = "eve-rift";
    inherit version src;
    extraBwrapArgs = [
      "--bind"
      "${self.user.home}/.cache/RIFT-tmp"
      "/tmp"
    ];
  };
  eveRift = pkgs.writeShellScriptBin "eve-rift" ''
    mkdir -p "${self.user.home}/.cache/RIFT-tmp"
    exec ${appimage}/bin/eve-rift "$@"
  '';
in
{
  name = "eve-rift";
  description = "EVE Online intel tool";

  group = "games";
  input = "linux";

  module = {
    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri.settings.window-rules = [
        {
          matches = [ { app-id = "^dev-nohus-rift-MainKt$"; } ];
          open-floating = false;
        }
      ];
    };

    home = config: {
      home.packages = [
        eveRift
        pkgs.xwininfo
        pkgs.xprop
      ];

      xdg.dataFile."icons/hicolor/256x256/apps/eve-rift.png".source = icon;

      xdg.dataFile."applications/dev.nohus.rift.window.desktop".text = ''
        [Desktop Entry]
        Hidden=true
      '';

      xdg.desktopEntries.eve-rift = {
        name = "RIFT Intel Fusion Tool";
        exec = "${eveRift}/bin/eve-rift %U";
        icon = "eve-rift";
        terminal = false;
        categories = [ "Game" ];
        settings.StartupWMClass = "dev-nohus-rift-MainKt";
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/RIFT"
          ".cache/RIFT"
        ];
      };
    };
  };
}
