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
  name = "qutebrowser";

  group = "browser";
  input = "linux";
  namespace = "home";

  unfree = [ "widevine-cdm" ];

  submodules = {
    common = {
      browser = {
        qutebrowser-config = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      customPkgs = self.pkgs-unstable {
        overlays = [
          (final: prev: {
            qutebrowser =
              let
                qbWithWideVine = prev.qutebrowser.override {
                  enableWideVine = true;
                };
              in
              qbWithWideVine.overrideAttrs (oldAttrs: {
                propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [
                  final.python3Packages.pyqt6
                  final.python3Packages.adblock
                  final.python3Packages.pynacl
                ];
                buildInputs = oldAttrs.buildInputs ++ [
                  prev.curl
                ];
                nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
                  prev.makeWrapper
                ];
                postInstall = oldAttrs.postInstall or "" + ''
                  wrapProgram $out/bin/qutebrowser \
                    --prefix LD_LIBRARY_PATH : "${prev.curl.out}/lib" \
                    --prefix XDG_DATA_DIRS : "${prev.gtk3}/share/gsettings-schemas/${prev.gtk3.name}:${prev.gsettings-desktop-schemas}/share"
                '';
              });
          })
        ];
      };
    in
    {
      programs.qutebrowser = {
        package = lib.mkForce customPkgs.qutebrowser;
      };
    };
}
