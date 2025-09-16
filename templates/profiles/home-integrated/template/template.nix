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

    modules = { };

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

    configuration =
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
      context@{ config, options, ... }:
      { };
  };
}
