{
  lib,
  pkgs,
  pkgs-unstable,
  variables,
  helpers,
  defs,
  self,
  ...
}:
{
  config.user = {
    username = "template";

    fullname = null;

    email = null;

    gpg = null;

    stateVersion = "25.11";

    additionalPackages = [ ];

    allowedUnfreePackages = [ ];

    modules = { }; # Attrset or list at GROUP level: { common.shell = [ "bash" "zsh" ]; }

    specialisations = { };

    settings = {
      desktop = null;
    };

    extraSettings = { };

    module = {
      # Overlays — applied unconditionally BEFORE pkgs is created. Cannot reference pkgs.
      # Each value is a list of (final: prev: { }) functions.
      # overlays = [ (final: prev: { ... }) ];

      # Runs for ALL modules (even disabled) in BOTH contexts.
      # Only set config.nx.* options here.
      # init = args@{ lib, self, ... }: context@{ config, options, ... }: { };

      # Runs in home context (both standalone and integrated)
      # home = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };

      # Platform-specific overrides
      # linux = {
      #   overlays = [ (final: prev: { ... }) ];
      #   init = args@{ lib, self, ... }: context@{ config, options, ... }: { };
      #   home = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      # };
      # darwin = {
      #   overlays = [ (final: prev: { ... }) ];
      #   init = args@{ lib, self, ... }: context@{ config, options, ... }: { };
      #   home = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      # };
    };
  };
}
