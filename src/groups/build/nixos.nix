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
        "hardware"
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
        "nixos-label"
      ]
      ++ lib.optionals (self.host.isVMHost or false) [ "vm-host" ];
      desktop = [ "desktop" ];
      programs = [ "programs" ];
      system = [ ] ++ (if self.host.impermanence or false then [ "impermanence" ] else [ ]);
      theme = [ "theme-system" ];
    };
  };
}
