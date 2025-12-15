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
  name = "bitwarden";

  group = "passwords";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      customPkgs = self.pkgs {
        overlays = [
          (final: prev: {
            bitwarden-cli = prev.bitwarden-cli.overrideAttrs (oldAttrs: {
              nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
              postInstall = (oldAttrs.postInstall or "") + ''
                wrapProgram $out/bin/bw \
                  --set BITWARDENCLI_APPDATA_DIR "${config.home.homeDirectory}/.config/Bitwarden-CLI"
              '';
            });
          })
        ];
      };
    in
    {
      home.packages = [
        pkgs.bitwarden
        customPkgs.bitwarden-cli
      ];

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+K" = {
              action = spawn-sh "niri-scratchpad --app-id Bitwarden --all-windows --spawn bitwarden";
              hotkey-overlay.title = "Apps:Bitwarden";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "Bitwarden";
                }
              ];
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
              block-out-from = "screencast";
            }
          ];
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/Bitwarden"
          ".config/Bitwarden-CLI"
        ];
      };
    };
}
