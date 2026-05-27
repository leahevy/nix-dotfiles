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
      ++ lib.optionals (self.host.isVMHost or false) [ "vm-host" ]
      ++ lib.optionals (self.host.crossBuild or false) [ "cross-build" ];
      desktop = [ "desktop" ];
      programs = [ "programs" ];
      system = [
        "kernel-fixes"
      ]
      ++ (if self.host.hardening or true then [ "hardening" ] else [ ])
      ++ (if self.host.impermanence or false then [ "impermanence" ] else [ ])
      ++ lib.optionals ((self.host.board or null) == "pi5") [ "raspberrypi" ];
      theme = [ "theme-system" ];
    };
  };
}
