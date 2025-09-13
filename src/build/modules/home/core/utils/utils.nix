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
  name = "utils";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        coreutils
        nettools
        inetutils
        unixtools.netstat
        findutils
        dnsutils
        gnused
        less
        gawk
        cron
        colordiff
      ];
    };
}
