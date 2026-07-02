{
  lib,
  inputs,
  build,
  variables,
}:
{
  mkLixModule =
    pkgs:
    lib.mkIf (variables."nix-implementation" == "lix") {
      nix.package = lib.mkForce pkgs.lix;
    };

  mkNiriDesktopModules = pkgs: [
    inputs.niri-flake.nixosModules.niri
    {
      programs.niri.package = lib.mkDefault pkgs.niri;
      niri-flake.cache.enable = false;
    }
  ];

  mkPersistenceDummy =
    { path, description }:
    {
      options = lib.setAttrByPath (lib.splitString "." path) (
        lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = description;
        }
      );
      config = { };
    };

  niriOptionsStub = {
    options.programs.niri = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };

  homeManagerBaseSharedModules = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.nixvim.homeModules.nixvim
    inputs.nix-index-database.homeModules.default
  ];

  mkHomeManagerSettings = specialArgs: {
    useGlobalPkgs = false;
    useUserPackages = true;
    backupFileExtension = variables.home-manager-backup-extension;
    extraSpecialArgs = specialArgs;
  };

  mkHomeManagerUserModules =
    { buildArgs, users }:
    builtins.attrValues (
      builtins.mapAttrs (
        username: user:
        lib.mkIf (user.home-manager or false) {
          home-manager.users.${username} = import (build + "/config/home/home-integrated.nix") (
            buildArgs
            // {
              user = user;
            }
          );
        }
      ) (lib.filterAttrs (_: user: user.home-manager or false) users)
    );
}
