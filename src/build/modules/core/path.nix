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
  group = "core";
  input = "build";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.sessionPath = [
        "${self.user.home}/.local/bin"
      ];
    };
}
