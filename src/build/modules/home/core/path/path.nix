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
  name = "path";

  configuration =
    context@{ config, options, ... }:
    {
      home.sessionPath = [
        "${self.user.home}/.local/bin"
      ];
    };
}
