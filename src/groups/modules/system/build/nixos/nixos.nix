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

  group = "build";
  input = "groups";
  namespace = "system";

  submodules = {
    build = {
      core = {
        boot = true;
        journal = true;
        sudo = true;
        i18n = true;
        network = true;
        users = true;
        nix-ld = true;
        tokens = true;
        sops = true;
        nx-config = true;
      };
      desktop = {
        desktop = true;
      };
      programs = {
        programs = true;
      };
      system = { } // (if self.host.impermanence or false then { impermanence = true; } else { });
      theme = {
        theme-system = true;
      };
    };
  };
}
