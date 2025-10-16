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
  name = "session";

  group = "shell";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home = {
        sessionVariables = {
          EDITOR = "vim";
          VISUAL = "emacs";
          PAGER = "bat";
          H = self.user.home;
        }
        // (self.settings.additionalEnvironment or { });

        shellAliases = {
          l = "ls";
          ls = "ls --color=auto";
          "l." = "ls -d .* --color=auto";
          ll = "ls -la --color=auto";
          rm = if self.isLinux then "rm -I --preserve-root" else "rm -I";
          mv = "mv -i";
          cp = "cp -i";
          ln = "ln -i";
          chown = if self.isLinux then "chown --preserve-root" else "chown";
          chmod = if self.isLinux then "chmod --preserve-root" else "chmod";
          chgrp = if self.isLinux then "chgrp --preserve-root" else "chgrp";
          mkdir = "mkdir -pv";
          ".." = "cd ..";
          "..." = "cd ../..";
          "...." = "cd ../../..";
          c = "clear";
          grep = "grep --color=auto";
          egrep = "egrep --color=auto";
          fgrep = "fgrep --color=auto";
          bc = "bc -l";
          diff = "colordiff";
          mountc = "mount | column -t";
          h = "history";
          j = "jobs -l";
          ping = "ping -c 5";
          ports = "netstat -tulanp";
          cpuinfo = "lscpu";
          top = "htop";
          iotop = "sudo iotop";
          iotop-most = "sudo iotop -ao";

          vim = "vim -p";
          vi = "vim -p";
          v = "vim -p";

          g = "git";
          gm = "g commit -m";
          gct = "g commit";
          gcn = "gct -m";
          gl = "g log";
          gg = "g graph";
          gps = "g push";
          gpl = "g pull";
          gs = "g status";
          gsth = "g stash";
          gsta = "gsth apply";
          ga = "g addp";
          gall = "g add .";
          gd = "g diff";
          gdc = "g diffc";

          dotfiles-init-bare = "/usr/bin/env git init --bare $HOME/.dotfiles";
          dotfiles = "/usr/bin/env git --git-dir=\"$HOME/.dotfiles/\" --work-tree=\"$HOME\"";
          dotfiles-configure = "/usr/bin/env git --git-dir=\"$HOME/.dotfiles/\" --work-tree=\"$HOME\" config status.showUntrackedFiles no";

          home = "cd $HOME";
          x = "z";

          dev-create = "nix flake init --template github:cachix/devenv";
          nix-search = "nix-env -f '<nixpkgs>' -qaP";
        }
        // (self.settings.additionalAliases or { });

        persistence."${self.persist}" = {
          directories = [
            ".dotfiles"
          ];
        };
      };
    };
}
