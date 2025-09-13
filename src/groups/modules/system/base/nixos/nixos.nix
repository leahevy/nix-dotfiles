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
            sshd = true;
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
          boot = {
            plymouth = true;
          };
        };
      }
    else
      { };
}
