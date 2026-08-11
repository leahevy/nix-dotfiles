args@{
  lib,
  pkgs,
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

  module = {
    enabled = config: {
      nx.common.dev.agents.programs = {
        wget = {
          purpose = "recursive or mirrored downloads";
          order = 70;
        };
        jd = {
          purpose = "structured JSON diff and patch";
          attr = "jd-diff-patch";
          order = 120;
        };
      };
    };

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

    linux.system = config: {
      environment.systemPackages = with pkgs; [
        nixos-rebuild
      ];
    };
  };
}
