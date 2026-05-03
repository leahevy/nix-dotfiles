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
        common.style = lib.optionals (self.host.settings.system.desktop != null) [ "stylix" ];
        linux = {
          memory = [ "zram" ];
          storage = lib.optionals self.isPhysical [ "smartd" ];
          system = [
            "gc"
            "timesyncd"
            "tmp"
          ];
          services = [
            "sshd"
          ];
          networking = [ "firewall" ];
        }
        // lib.optionalAttrs (self.host.settings.system.desktop != null) {
          boot = [ "plymouth" ];
        };
      }
    else
      { };
}
