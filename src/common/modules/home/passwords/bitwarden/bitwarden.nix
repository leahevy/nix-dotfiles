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

      home.persistence."${self.persist}" = {
        directories = [
          ".config/Bitwarden"
          ".config/Bitwarden-CLI"
        ];
      };
    };
}
