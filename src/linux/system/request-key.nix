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
  name = "request-key";
  group = "system";
  input = "linux";
  description = "Kernel request-key userspace helper for key instantiation.";

  options = {
    rules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Entries added to /etc/request-key.conf for kernel key instantiation handlers.";
    };
  };

  module = {
    linux.system =
      { config, rules, ... }:
      {
        environment.systemPackages = [ pkgs.keyutils ];
        environment.etc."request-key.conf".text = lib.concatStringsSep "\n" rules + "\n";
        systemd.tmpfiles.settings."request-key-sbin"."/sbin/request-key"."L+" = {
          argument = "${pkgs.keyutils}/bin/request-key";
        };
      };
  };
}
