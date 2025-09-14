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
  name = "todoist";

  unfree = [ "todoist-electron" ];

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs-unstable; [
        todoist-electron
      ];

      home.persistence."${self.persist}" = {
        directories = [ ".config/Todoist" ];
      };
    };
}
