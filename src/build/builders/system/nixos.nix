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
    processHostProfile
    ;

  homeIntegrated = import (build + "/builders/home/home-integrated.nix") {
    inherit
      lib
      inputs
      build
      variables
      ;
  };

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
        lib
        specialArgs
        buildArgs
        diskoModule
        hardwareModule
        ;
      isNiriDesktop = hostConfig.host.settings.system.desktop == "niri";
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
        ]
        ++ lib.optionals isNiriDesktop [
          inputs.niri-flake.nixosModules.niri
          {
            programs.niri.package = lib.mkDefault pkgs.niri;
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
        ]
        ++ (homeIntegrated.mkHomeIntegratedModules {
          inherit
            pkgs
            buildArgs
            specialArgs
            isNiriDesktop
            ;
          host = hostConfig.host;
          users = hostConfig.users;
          homeManagerModule = inputs.home-manager.nixosModules.home-manager;
        });
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

}
