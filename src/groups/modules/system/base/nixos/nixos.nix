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

  submodules =
    if self ? isLinux && self.isLinux then
      {
        common = {
          services = {
            printing = true;
          };
          style = {
            stylix = true;
          };
          system = {
            gc = true;
            auto-upgrades = true;
            timesyncd = true;
            tmp = true;
          };
        };
        linux = {
          services = {
            sshd = true;
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
