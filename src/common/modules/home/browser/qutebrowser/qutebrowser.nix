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

  configuration =
    context@{ config, options, ... }:
    {
      nixpkgs.overlays = [
        (final: prev: {
          qutebrowser = prev.qutebrowser.override { enableWideVine = true; };
        })
      ];

      home = {
        packages = with pkgs; [
          qutebrowser
        ];
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/qutebrowser"
          ".local/share/qutebrowser"
          ".cache/qutebrowser"
        ];
      };
    };
}
