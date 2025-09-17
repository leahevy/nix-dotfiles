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
  name = "home-manager";
  description = "Home Manager base group";

  submodules =
    # NixOS Integrated
    if
      (self ? isLinux && self.isLinux)
      && (self ? user && self.user ? isStandalone && !self.user.isStandalone)
    then
      {
        common = {
          xdg = {
            user-dirs = true;
          };
          utils = {
            archive-tools = true;
          };
          browser = {
            qutebrowser = true;
          };
          dev = {
            devenv = true;
            cmake = true;
            utils = true;
            direnv = true;
            claude = true;
            nodejs = true;
            typescript-lsp = true;
          };
          fonts = {
            fontconfig = true;
            nerdfonts = true;
          };
          git = {
            git = true;
            git-credential-manager = true;
          };
          gpg = {
            gpg = true;
          };
          nix = {
            nix-index = true;
            comma = true;
          };
          passwords = {
            keepassxc = true;
          };
          python = {
            python = true;
            setup = true;
          };
          shell = {
            starship = true;
            file-manager = true;
            go-programs = true;
          };
          spell = {
            ispell = true;
          };
          sshd = {
            ssh-agent = true;
          };
          tmux = {
            tmux = true;
          };
          nvim = {
            nixvim = true;
          };
          emacs = {
            emacs = true;
            doom = true;
          };
          chat = {
            beeper = true;
            signal = true;
          };
          todo = {
            todoist = true;
          };
          music = {
            spotify = true;
          };
        };
        linux = {
          utils = {
            alien = true;
          };
          gnome = {
            keyring = true;
            gtk = true;
          };
          services = {
            ssh-agent = true;
          };
        };
        groups = {
          shell = {
            shell = true;
          };
        };
      }
    # Linux standalone
    else if
      (self ? isLinux && self.isLinux)
      && (self ? user && self.user ? isStandalone && self.user.isStandalone)
    then
      {
        common = {
          xdg = {
            user-dirs = true;
          };
          utils = {
            archive-tools = true;
          };
          browser = {
            qutebrowser = true;
          };
          dev = {
            devenv = true;
            cmake = true;
            utils = true;
            direnv = true;
            claude = true;
            nodejs = true;
            typescript-lsp = true;
          };
          fonts = {
            fontconfig = true;
            nerdfonts = true;
          };
          git = {
            git = true;
            git-credential-manager = true;
          };
          gpg = {
            gpg = true;
          };
          nix = {
            nix-index = true;
            comma = true;
          };
          passwords = {
            keepassxc = true;
          };
          python = {
            python = true;
            setup = true;
          };
          shell = {
            starship = true;
            file-manager = true;
            go-programs = true;
          };
          spell = {
            ispell = true;
          };
          style = {
            stylix = true;
          };
          tmux = {
            tmux = true;
          };
          nvim = {
            nixvim = true;
          };
          emacs = {
            emacs = true;
            doom = true;
          };
          chat = {
            beeper = true;
            signal = true;
          };
          todo = {
            todoist = true;
          };
          music = {
            spotify = true;
          };
        };
        linux = {
          utils = {
            alien = true;
          };
          gnome = {
            keyring = true;
          };
          services = {
            ssh-agent = true;
          };
        };
        groups = {
          shell = {
            shell = true;
          };
        };
      }
    # MacOS Standalone
    else if
      (self ? isDarwin && self.isDarwin)
      && (self ? user && self.user ? isStandalone && self.user.isStandalone)
    then
      {
        common = {
          utils = {
            archive-tools = true;
          };
          dev = {
            devenv = true;
            cmake = true;
            utils = true;
            direnv = true;
            claude = true;
            nodejs = true;
            typescript-lsp = true;
          };
          fonts = {
            fontconfig = true;
            nerdfonts = true;
          };
          git = {
            git = true;
            git-credential-manager = true;
          };
          gpg = {
            gpg = true;
          };
          nix = {
            nix-index = true;
            comma = true;
          };
          passwords = {
            keepassxc = true;
          };
          python = {
            python = true;
            setup = true;
          };
          shell = {
            starship = true;
            file-manager = true;
            go-programs = true;
          };
          spell = {
            ispell = true;
          };
          style = {
            stylix = true;
          };
          tmux = {
            tmux = true;
          };
          nvim = {
            nixvim = true;
          };
          emacs = {
            emacs = true;
            doom = true;
          };
        };
        groups = {
          shell = {
            shell = true;
          };
        };
      }
    else
      { };
}
