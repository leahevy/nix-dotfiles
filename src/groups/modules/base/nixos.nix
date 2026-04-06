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
  name = "nixos";
  description = "NixOS base group module";

  group = "base";
  input = "groups";

  submodules =
    if self ? isLinux && self.isLinux then
      {
        common.style = [ "stylix" ];
        linux = {
          memory = [ "zram" ];
          storage = [ "smartd" ];
          system = [
            "gc"
            "auto-upgrades"
            "timesyncd"
            "tmp"
          ];
          services = [
            "sshd"
            "printing"
            "scanning"
          ];
          networking = [ "firewall" ];
          boot = [ "plymouth" ];
        };
      }
    else
      { };
}
