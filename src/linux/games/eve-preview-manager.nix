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
  version = "1.9.0";
  icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/h0lylag/EVE-Preview-Manager/v${version}/assets/com.evepreview.manager.png";
    hash = "sha256-wYwF2b964aDfNOHMjtX9/YbuUb54AHnmWjwzo+IjSRI=";
  };
  src = pkgs.fetchzip {
    url = "https://github.com/h0lylag/EVE-Preview-Manager/releases/download/v${version}/eve-preview-manager-v${version}.zip";
    hash = "sha256-GyfrgukaGfB/ydJAUF8uZqBqc6HdeWd0GQK8c5Y88JY=";
    stripRoot = false;
  };
  evePreviewManager = pkgs.stdenv.mkDerivation {
    pname = "eve-preview-manager";
    inherit version src;

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.libGL
      pkgs.libxkbcommon
      pkgs.wayland
      pkgs.libx11
      pkgs.libxcursor
      pkgs.libxrandr
      pkgs.libxi
      pkgs.fontconfig
    ];
    runtimeDependencies = [
      pkgs.stdenv.cc.cc.lib
      pkgs.libGL
      pkgs.libxkbcommon
      pkgs.wayland
      pkgs.libx11
      pkgs.libxcursor
      pkgs.libxrandr
      pkgs.libxi
    ];

    installPhase = ''
      mkdir -p $out/bin
      cp $src/eve-preview-manager $out/bin/
    '';
  };
in
{
  name = "eve-preview-manager";
  description = "EVE Online multiboxing window preview tool";

  group = "games";
  input = "linux";

  assertions = [
    {
      assertion = helpers.getDesktop self != "niri";
      message = "EVE Preview Manager does not work on niri: it requires EWMH (_NET_CLIENT_LIST, _NET_ACTIVE_WINDOW, override_redirect) which niri does not implement on XWayland!";
    }
  ];

  module = {
    enabled = config: {
      nx.common.browser.browser.bookmarks = {
        "Games" = {
          "EVE Online" = {
            "Community" = {
              "EVE Preview Manager" = "https://epm.sh/";
            };
          };
        };
      };
    };

    home = config: {
      home.packages = [ evePreviewManager ];

      xdg.dataFile."icons/hicolor/256x256/apps/eve-preview-manager.png".source = icon;

      xdg.desktopEntries.eve-preview-manager = {
        name = "EVE Preview Manager";
        exec = "${evePreviewManager}/bin/eve-preview-manager";
        icon = "eve-preview-manager";
        terminal = false;
        categories = [ "Game" ];
      };

      home.persistence."${self.persist}" = {
        directories = [ ".config/eve-preview-manager" ];
      };
    };
  };
}
