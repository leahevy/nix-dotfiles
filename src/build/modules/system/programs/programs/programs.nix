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
  name = "programs";
  group = "programs";
  input = "build";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      environment.systemPackages =
        with pkgs;
        [
          git
          file
          htop
          btop
          vim
          nixfmt-rfc-style
          nixfmt-tree
          nix-prefetch-github
          git-crypt
          pre-commit
          sops
          age
          ssh-to-age
          ssh-to-pgp
          iotop
          gnupg
          killall
          nvd
          keyutils
          usbutils
          pciutils
          hwinfo
          psmisc
          lsof
          tree
        ]
        ++ (if self.isLinux then with pkgs; [ pinentry-curses ] else [ ]);

      programs = {
        zsh.enable = true;
        fish.enable = true;
        nh.enable = true;
        gnupg.agent = {
          enable = true;
          pinentryPackage = if self.isLinux then pkgs.pinentry-curses else null;
          enableSSHSupport = true;
        };
      };
    };
}
