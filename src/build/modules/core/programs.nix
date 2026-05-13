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
  group = "core";
  input = "build";

  module = {
    ifDisabled.common.python.python.home = config: {
      home.packages = [ pkgs.${self.variables.pythonName} ];
    };

    standalone = config: {
      home.file = {
        ".local/bin/nix".source = config.nix.package.out + "/bin/nix";
        ".local/bin/nix-build".source = config.nix.package.out + "/bin/nix-build";
        ".local/bin/nix-channel".source = config.nix.package.out + "/bin/nix-channel";
        ".local/bin/nix-collect-garbage".source = config.nix.package.out + "/bin/nix-collect-garbage";
        ".local/bin/nix-copy-closure".source = config.nix.package.out + "/bin/nix-copy-closure";
        ".local/bin/nix-env".source = config.nix.package.out + "/bin/nix-env";
        ".local/bin/nix-hash".source = config.nix.package.out + "/bin/nix-hash";
        ".local/bin/nix-instantiate".source = config.nix.package.out + "/bin/nix-instantiate";
        ".local/bin/nix-prefetch-url".source = config.nix.package.out + "/bin/nix-prefetch-url";
        ".local/bin/nix-shell".source = config.nix.package.out + "/bin/nix-shell";
        ".local/bin/nix-store".source = config.nix.package.out + "/bin/nix-store";
      };
    };

    home = config: {
      home = {
        packages = with pkgs; [
          jq
          openssl
          tree
          git
          htop
          vim
          shfmt
          shellcheck
          nix-output-monitor
          nixfmt-rfc-style
          nixfmt-tree
          nix-search
          nix-prefetch-github
          git-crypt
          sops
          age
          ssh-to-age
          ssh-to-pgp
          nvd
        ];
      };
    };

    linux.home = config: {
      home = {
        packages = with pkgs; [
          pre-commit
        ];
      };
    };

    darwin.enabled = config: {
      nx.homebrew.brews = [ "pre-commit" ];
    };
  };
}
