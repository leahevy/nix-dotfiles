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

  group = "base";
  input = "groups";
  namespace = "home";

  submodules =
    # NixOS Integrated
    if
      (self ? isLinux && self.isLinux)
      && (self ? user && self.user ? isStandalone && !self.user.isStandalone)
    then
      {
        common = {
          text = {
            latex = true;
          };
          utils = {
            archive-tools = true;
          };
          browser = {
            firefox = true;
          };
          dev = {
            conda = true;
            poetry = true;
            devenv = true;
            cmake = true;
            utils = true;
            direnv = true;
            claude = true;
            nodejs = true;
            typescript-lsp = true;
            vscodium = true;
          };
          fonts = {
            japanese = true;
            general = true;
            fontconfig = true;
            nerdfonts = true;
          };
          git = {
            git = true;
            lazygit = true;
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
          };
          shell = {
            fastfetch = true;
            starship = true;
            file-manager = true;
            go-programs = true;
            timg = true;
          };
          spell = {
            ispell = true;
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
            fluffychat = true;
          };
        };
        linux = {
          notifications = {
            user-notify = true;
          };
          chat = {
            beeper = true;
            signal = true;
          };
          browser = {
            qutebrowser = true;
          };
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
          todo = {
            todoist = true;
          };
          xdg = {
            user-dirs = true;
          };
          music = {
            spotify = true;
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
          text = {
            latex = true;
          };
          utils = {
            archive-tools = true;
          };
          browser = {
            firefox = true;
          };
          dev = {
            conda = true;
            poetry = true;
            devenv = true;
            cmake = true;
            utils = true;
            direnv = true;
            claude = true;
            nodejs = true;
            typescript-lsp = true;
            vscodium = true;
          };
          fonts = {
            japanese = true;
            general = true;
            fontconfig = true;
            nerdfonts = true;
          };
          git = {
            git = true;
            lazygit = true;
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
          };
          shell = {
            fastfetch = true;
            starship = true;
            file-manager = true;
            go-programs = true;
            timg = true;
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
            fluffychat = true;
          };
        };
        linux = {
          chat = {
            beeper = true;
            signal = true;
          };
          browser = {
            qutebrowser = true;
          };
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
          todo = {
            todoist = true;
          };
          xdg = {
            user-dirs = true;
          };
          music = {
            spotify = true;
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
          text = {
            latex = true;
          };
          utils = {
            archive-tools = true;
          };
          browser = {
            firefox = true;
          };
          dev = {
            conda = true;
            poetry = true;
            devenv = true;
            cmake = true;
            utils = true;
            direnv = true;
            claude = true;
            nodejs = true;
            typescript-lsp = true;
            vscodium = true;
          };
          fonts = {
            japanese = true;
            general = true;
            fontconfig = true;
            nerdfonts = true;
          };
          git = {
            git = true;
            lazygit = true;
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
          };
          shell = {
            fastfetch = true;
            starship = true;
            file-manager = true;
            go-programs = true;
            timg = true;
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
            fluffychat = true;
          };
        };
        darwin = {
          software = {
            homebrew = true;
          };
          browser = {
            firefox = true;
            qutebrowser = true;
          };
          chat = {
            beeper = true;
            slack = true;
          };
          desktop = {
            yabai = true;
          };
          dev = {
            conda = true;
          };
          music = {
            spotify = true;
          };
          organising = {
            logseq = true;
          };
          passwords = {
            keepassxc = true;
          };
          terminal = {
            ghostty = true;
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
