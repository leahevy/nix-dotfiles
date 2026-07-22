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
  name = "nixos";
  description = "NixOS base group module";

  group = "base";
  input = "groups";

  submodules =
    if self ? isLinux && self.isLinux then
      {
        common.style = lib.optionals (helpers.hasDesktop self) [ "stylix" ];
        linux = {
          memory = [ "zram" ];
          security = lib.optionals self.host.settings.security.auditd.enable [ "auditd" ];
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
        // lib.optionalAttrs (helpers.hasDesktop self) {
          boot = [ "plymouth" ];
        };
      }
    else
      { };
}
