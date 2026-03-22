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
  group = "core";
  input = "build";

  on = {
    home = config: {
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
        wget
        killall
        jd-diff-patch
        nix-diff
      ];
    };
  };
}
