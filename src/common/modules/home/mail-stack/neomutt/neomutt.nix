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
  name = "neomutt";
  group = "mail-stack";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      mail-stack = {
        accounts = true;
        mbsync = true;
        msmtp = true;
        notmuch = true;
      };
    };
  };

  settings = { };

  configuration =
    context@{ config, options, ... }:
    {
    };
}
