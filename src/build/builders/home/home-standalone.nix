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
  standalone-user-files,
  allArchitectures,
}:

let
  inherit (common)
    processStandaloneUserProfile
    ;

  buildHomeConfiguration =
    {
      profileName,
      arch,
      buildArch ? arch,
    }:
    let
      processResult = processStandaloneUserProfile { inherit profileName arch buildArch; };
      inherit (processResult) buildContext;
      inherit (buildContext)
        pkgs
        lib
        buildArgs
        extraUserModule
        ;
    in
    {
      name =
        if buildArch == arch then "${profileName}--${arch}" else "${profileName}--${arch}--${buildArch}";
      value = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          (import (build + "/config/home/home-standalone.nix") buildArgs)
          (lib.mkIf (variables."nix-implementation" == "lix") {
            nix.package = lib.mkForce pkgs.lix;
          })
          inputs.sops-nix.homeManagerModules.sops
          inputs.stylix.homeModules.stylix
          inputs.nixvim.homeModules.nixvim
        ]
        ++ (lib.optionals (helpers.isLinuxArch arch) [
          inputs.niri-flake.homeModules.niri
          inputs.niri-flake.homeModules.stylix
        ])
        ++ (lib.optionals (helpers.isDarwinArch arch) [
          {
            options.programs.niri = lib.mkOption {
              type = lib.types.attrs;
              default = { };
            };
            config.lib.niri.actions.spawn = _: null;
            config.lib.niri.actions.spawn-sh = _: null;
          }
        ])
        ++ [
          {
            options.home.persistence = lib.mkOption {
              type = lib.types.attrs;
              default = { };
              description = "Persistence configuration (stub for standalone Home Manager)";
            };
            config = { };
          }
        ]
        ++ extraUserModule
        ++ (if helpers.isDarwinArch arch then [ inputs.mac-app-util.homeManagerModules.default ] else [ ])
        ++ (
          if helpers.isDarwinArch arch then [ inputs.nix-plist-manager.homeManagerModules.default ] else [ ]
        );
      };
    };

in

{
  buildHomeConfigurations = builtins.listToAttrs (
    lib.flatten (
      map (
        profileName:
        (map (arch: buildHomeConfiguration { inherit profileName arch; }) allArchitectures)
        ++ (lib.flatten (
          map (
            arch:
            map (buildArch: buildHomeConfiguration { inherit profileName arch buildArch; }) (
              lib.filter (b: b != arch) allArchitectures
            )
          ) allArchitectures
        ))
      ) standalone-user-files
    )
  );

}
