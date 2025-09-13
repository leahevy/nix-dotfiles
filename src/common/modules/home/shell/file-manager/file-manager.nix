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
  name = "file-manager";

  configuration =
    context@{ config, options, ... }:
    {
      home = {
        packages = with pkgs; [
          mc
          ranger
        ];
      };
    };
}
