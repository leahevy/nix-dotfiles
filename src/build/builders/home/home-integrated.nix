{
  lib,
  inputs,
  build,
  variables,
}:
{
  mkHomeIntegratedModules =
    {
      pkgs,
      host,
      users,
      buildArgs,
      specialArgs,
      isNiriDesktop ? false,
      homeManagerModule,
    }:
    [
      homeManagerModule
      {
        home-manager.sharedModules = [
          inputs.sops-nix.homeManagerModules.sops
          inputs.nixvim.homeModules.nixvim
          inputs.nix-index-database.homeModules.default
          (lib.mkIf (variables."nix-implementation" == "lix") {
            nix.package = lib.mkForce pkgs.lix;
          })
        ]
        ++ lib.optionals (!isNiriDesktop) [
          {
            options.programs.niri = lib.mkOption {
              type = lib.types.attrs;
              default = { };
            };
          }
        ]
        ++ (
          if !(host.impermanence or false) then
            [
              {
                options.home.persistence = lib.mkOption {
                  type = lib.types.attrs;
                  default = { };
                  description = "Persistence configuration (dummy for non-impermanent systems)";
                };
                config = { };
              }
            ]
          else
            [ ]
        );
        home-manager.useGlobalPkgs = false;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "nix-rebuild.backup";
        home-manager.extraSpecialArgs = specialArgs;
      }
    ]
    ++ (builtins.attrValues (
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
    ));
}
