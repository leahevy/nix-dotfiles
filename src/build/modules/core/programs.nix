args@{
  lib,
  pkgs,
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
      home.packages = [ pkgs.python3 ];
    };

    standalone = config: {
      home.file = {
        "${defs.binDir}/nix".source = config.nix.package.out + "/bin/nix";
        "${defs.binDir}/nix-build".source = config.nix.package.out + "/bin/nix-build";
        "${defs.binDir}/nix-channel".source = config.nix.package.out + "/bin/nix-channel";
        "${defs.binDir}/nix-collect-garbage".source = config.nix.package.out + "/bin/nix-collect-garbage";
        "${defs.binDir}/nix-copy-closure".source = config.nix.package.out + "/bin/nix-copy-closure";
        "${defs.binDir}/nix-env".source = config.nix.package.out + "/bin/nix-env";
        "${defs.binDir}/nix-hash".source = config.nix.package.out + "/bin/nix-hash";
        "${defs.binDir}/nix-instantiate".source = config.nix.package.out + "/bin/nix-instantiate";
        "${defs.binDir}/nix-prefetch-url".source = config.nix.package.out + "/bin/nix-prefetch-url";
        "${defs.binDir}/nix-shell".source = config.nix.package.out + "/bin/nix-shell";
        "${defs.binDir}/nix-store".source = config.nix.package.out + "/bin/nix-store";
      };
    };

    home = config: {
      home = {
        packages = with pkgs; [
          jq
          yq
          openssl
          tree
          git
          htop
          vim
          shfmt
          shellcheck
          nix-output-monitor
          nixfmt
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
