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
    getHardwareModule
    getDiskoModule
    processHostProfile
    ;

  buildNixOSConfiguration =
    {
      profileName,
      arch,
      buildArch ? arch,
    }:
    let
      processResult = processHostProfile { inherit profileName arch buildArch; };
      inherit (processResult) hostConfig buildContext;
      inherit (buildContext)
        system
        pkgs
        pkgs-unstable
        lib
        specialArgs
        buildArgs
        diskoModule
        hardwareModule
        ;
    in
    {
      name =
        if buildArch == arch then "${profileName}--${arch}" else "${profileName}--${arch}--${buildArch}";
      value = inputs.nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = specialArgs;
        modules = [
          (import (build + "/config/system/nixos.nix") buildArgs)
          inputs.sops-nix.nixosModules.sops
          inputs.stylix.nixosModules.stylix
          inputs.nixvim.nixosModules.nixvim
          inputs.niri-flake.nixosModules.niri
          {
            niri-flake.cache.enable = false;
          }
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
        ++ hardwareModule
        ++ diskoModule
        ++ [
          (lib.mkIf (variables."nix-implementation" == "lix") {
            nix.package = lib.mkForce pkgs.lix;
          })
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.sharedModules = [
              inputs.sops-nix.homeManagerModules.sops
              inputs.nixvim.homeModules.nixvim
              (lib.mkIf (variables."nix-implementation" == "lix") {
                nix.package = lib.mkForce pkgs.lix;
              })
            ]
            ++ (
              if !(hostConfig.host.impermanence or false) then
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
          ) (lib.filterAttrs (_: user: user.home-manager or false) hostConfig.users)
        ));
      };
    };
in
{
  buildNixOSConfigurations = builtins.listToAttrs (
    lib.flatten (
      map (
        profileName:
        (map (arch: buildNixOSConfiguration { inherit profileName arch; }) nixosArchitectures)
        ++ (lib.flatten (
          map (
            arch:
            map (buildArch: buildNixOSConfiguration { inherit profileName arch buildArch; }) (
              lib.filter (b: b != arch) nixosArchitectures
            )
          ) nixosArchitectures
        ))
      ) host-files
    )
  );

  extractHosts =
    lib.genAttrs
      (lib.flatten (
        map (profileName: map (arch: "${profileName}--${arch}") nixosArchitectures) host-files
      ))
      (
        key:
        let
          parts = lib.splitString "--" key;
          profileName = builtins.head parts;
          arch = lib.last parts;
        in
        (processHostProfile { inherit profileName arch; }).hostConfig
      );
}
