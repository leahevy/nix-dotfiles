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
  version = "2.0.6";
  rev = "b483f1ed8ab4f585b5f11bb46b9284a0436d901c";
  icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/mintnick/eve-settings-manager/${rev}/public/logo.png";
    hash = "sha256-waeLTUwoaQr26ztW5KiEb7G6XsqNSAS4LfrJXEof8dI=";
  };
  src = pkgs.fetchurl {
    url = "https://github.com/mintnick/eve-settings-manager/releases/download/v${version}/EVE-Settings-Manager-Linux-${version}.AppImage";
    sha256 = "075ga7qw65qzckymy2h4g1kklc0kvjjq6j8bi4s50rj1ab5cpsk0";
  };
  appimage = pkgs.appimageTools.wrapType2 {
    pname = "eve-settings-manager";
    inherit version src;
  };
  eveSettingsManager = pkgs.writeShellScriptBin "eve-settings-manager" ''
    exec ${appimage}/bin/eve-settings-manager --user-data-dir="${self.user.home}/.config/eve-settings-manager" "$@"
  '';
in
{
  name = "eve-settings-manager";
  description = "EVE Online settings manager";

  group = "games";
  input = "linux";

  module = {
    home = config: {
      home.packages = [ eveSettingsManager ];

      xdg.desktopEntries.eve-settings-manager = {
        name = "EVE Settings Manager";
        exec = "${eveSettingsManager}/bin/eve-settings-manager %U";
        icon = "${icon}";
        terminal = false;
        categories = [ "Game" ];
      };

      home.persistence."${self.persist}" = {
        directories = [ ".config/eve-settings-manager" ];
      };
    };
  };
}
