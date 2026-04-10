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

  submodules = {
    build = {
      core = [
        "boot"
        "journal"
        "sudo"
        "i18n"
        "network"
        "users"
        "nix-ld"
        "tokens"
        "sops"
        "nx-config"
        "firmware"
        "sysctl"
        "homebrew"
        "profile"
      ];
      desktop = [ "desktop" ];
      programs = [ "programs" ];
      system = [ ] ++ (if self.host.impermanence or false then [ "impermanence" ] else [ ]);
      theme = [ "theme-system" ];
    };
  };
}
