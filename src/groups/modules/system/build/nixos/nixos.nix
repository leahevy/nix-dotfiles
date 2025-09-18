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

  description = "Build modules for NixOS system configuration";

  submodules = {
    build = {
      core = {
        boot = true;
        sudo = true;
        i18n = true;
        network = true;
        users = true;
        nix-ld = true;
        tokens = true;
        sops = true;
      };
      desktop = {
        desktop = true;
      };
      programs = {
        programs = true;
      };
      system = { } // (if self.host.impermanence or false then { impermanence = true; } else { });
    };
  };
}
