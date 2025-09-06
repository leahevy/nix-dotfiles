{
  lib,
  inputs,
  config,
  build,
  variables,
  helpers,
  defs,
  funcs,
  common,
  host-files,
  nixosArchitectures,
}:

let
  inherit (common)
    evalConfigModule
    setupPackages
    buildSpecialArgs
    getExtraModulePath
    getHardwareModule
    getDiskoModule
    processHostProfile
    ;

  buildNixOSConfiguration =
    { profileName, arch }:
    let
      processResult = processHostProfile { inherit profileName arch; };
      inherit (processResult) hostConfig buildContext;
      inherit (buildContext)
        system
        pkgs
        pkgs-unstable
        lib
        specialArgs
        buildArgs
        extraHostModule
        diskoModule
        hardwareModule
        ;
    in
    {
      name = "${profileName}--${arch}";
      value = inputs.nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = specialArgs;
        modules = [
          (import (build + "/config/system/nixos.nix") buildArgs)
          inputs.sops-nix.nixosModules.sops
          inputs.stylix.nixosModules.stylix
          inputs.nixvim.nixosModules.nixvim
        ]
        ++ (
          if hostConfig.host.impermanence or false then
            [ inputs.impermanence.nixosModules.impermanence ]
          else
            [
              {
                options.environment.persistence = lib.mkOption {
                  type = lib.types.attrs;
                  default = { };
                  description = "Persistence configuration (dummy for non-impermanent systems)";
                };
                config = { };
              }
            ]
        )
        ++ (map (path: import path buildArgs) extraHostModule)
        ++ hardwareModule
        ++ diskoModule
        ++ [
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.sharedModules = [
              inputs.sops-nix.homeManagerModules.sops
              inputs.nixvim.homeModules.nixvim
            ]
            ++ (
              if hostConfig.host.impermanence or false then
                [ inputs.impermanence.homeManagerModules.impermanence ]
              else
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
          ) (lib.filterAttrs (_: user: user.home-manager or false) hostConfig.users)
        ));
      };
    };
in
{
  buildNixOSConfigurations = builtins.listToAttrs (
    lib.flatten (
      map (
        profileName: map (arch: buildNixOSConfiguration { inherit profileName arch; }) nixosArchitectures
      ) host-files
    )
  );

  extractHosts = builtins.listToAttrs (
    lib.flatten (
      map (
        profileName:
        map (
          arch:
          let
            processResult = processHostProfile { inherit profileName arch; };
            hostInfo = processResult.hostConfig;
          in
          {
            name = "${hostInfo.hostname}--${arch}";
            value = hostInfo;
          }
        ) nixosArchitectures
      ) host-files
    )
  );
}
