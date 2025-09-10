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
  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        keepassxc
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/keepassxc"
          ".cache/keepassxc"
        ];
        files = [
          ".config/autostart/org.keepassxc.KeePassXC.desktop"
        ];
      };
    };
}
