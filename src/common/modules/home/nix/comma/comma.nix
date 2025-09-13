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
  name = "comma";

  configuration =
    context@{ config, options, ... }:
    {
      home = {
        packages = with pkgs-unstable; [
          comma
        ];
      };
    };
}
