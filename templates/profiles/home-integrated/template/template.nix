{
  lib,
  pkgs,
  pkgs-unstable,
  variables,
  helpers,
  defs,
  ...
}:
{
  config.user = {
    username = "template";

    fullname = null;

    email = null;

    gpg = null;

    additionalPackages = [ ];

    allowedUnfreePackages = [ ];

    home-manager = false;

    modules = { }; # Attrset or list at GROUP level: { common.shell = [ "bash" "zsh" ]; }

    specialisations = { };

    system = {
      createHome = true;
      group = null;
      extraGroups = [ ];
      systemdSessionAtBoot = true;
      isSystemUser = false;
      shell = "zsh";
    };

    settings = {
      sshd = {
        authorizedKeys = [ ];
      };
    };

    extraSettings = { };

    module = {
      # Runs for ALL modules (even disabled) in BOTH contexts.
      # Only set config.nx.* options here.
      # init = args@{ lib, self, ... }: context@{ config, options, ... }: { };

      # Runs in home context (both standalone and integrated)
      # home = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };

      # Runs in system context
      # system = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };

      # Platform-specific overrides
      # linux = {
      #   init = args@{ lib, self, ... }: context@{ config, options, ... }: { };
      #   home = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      #   system = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      # };
      # darwin = {
      #   init = args@{ lib, self, ... }: context@{ config, options, ... }: { };
      #   home = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      #   system = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      # };
    };
  };
}
