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
  namespace = "system";

  submodules =
    if self ? isLinux && self.isLinux then
      {
        common = {
          style = {
            stylix = true;
          };
        };
        linux = {
          system = {
            gc = true;
            auto-upgrades = true;
            timesyncd = true;
            tmp = true;
          };
          services = {
            sshd = true;
            printing = true;
            scanning = true;
          };
          networking = {
            firewall = true;
          };
          boot = {
            plymouth = true;
          };
        };
      }
    else
      { };
}
