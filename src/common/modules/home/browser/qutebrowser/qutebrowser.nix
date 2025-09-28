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

  unfree = [ "widevine-cdm" ];

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
                ];
                buildInputs = oldAttrs.buildInputs ++ [
                  prev.curl
                ];
                nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
                  prev.makeWrapper
                ];
                postInstall = oldAttrs.postInstall or "" + ''
                  wrapProgram $out/bin/qutebrowser \
                    --prefix LD_LIBRARY_PATH : "${prev.curl.out}/lib"
                '';
              });
          })
        ];
      };
    in
    {
      programs.qutebrowser = {
        enable = true;
        package = customPkgs.qutebrowser;
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/qutebrowser"
          ".local/share/qutebrowser"
          ".cache/qutebrowser"
        ];
      };

      home.sessionVariables = {
        BROWSER = "qutebrowser";
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = {
            "Ctrl+Mod+Alt+N" = {
              action = config.lib.niri.actions.spawn-sh "qutebrowser";
              hotkey-overlay.title = "Apps:Browser";
            };
          };
        };
      };
    };
}
