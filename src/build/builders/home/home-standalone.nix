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
    evalConfigModule
    setupPackages
    buildSpecialArgs
    processStandaloneUserProfile
    ;

  buildHomeConfiguration =
    { profileName, arch }:
    let
      processResult = processStandaloneUserProfile { inherit profileName arch; };
      inherit (processResult) userConfig buildContext;
      inherit (buildContext)
        system
        pkgs
        pkgs-unstable
        lib
        specialArgs
        buildArgs
        extraUserModule
        ;
    in
    {
      name = "${profileName}--${arch}";
      value = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          (import (build + "/config/home/home-standalone.nix") buildArgs)
          inputs.sops-nix.homeManagerModules.sops
          inputs.stylix.homeModules.stylix
          inputs.nixvim.homeModules.nixvim
        ]
        ++ (lib.optionals (helpers.isLinuxArch arch) [
          inputs.niri-flake.homeModules.niri
          inputs.niri-flake.homeModules.stylix
          {
            niri-flake.cache.enable = false;
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
        ++ (if helpers.isDarwinArch arch then [ inputs.mac-app-util.homeManagerModules.default ] else [ ]);
      };
    };

in

{
  buildHomeConfigurations = builtins.listToAttrs (
    lib.flatten (
      map (
        profileName: map (arch: buildHomeConfiguration { inherit profileName arch; }) allArchitectures
      ) standalone-user-files
    )
  );

  extractUsers = builtins.listToAttrs (
    lib.flatten (
      map (
        profileName:
        map (
          arch:
          let
            processResult = processStandaloneUserProfile { inherit profileName arch; };
            userInfo = processResult.userConfig;
          in
          {
            name = "${userInfo.username}--${arch}";
            value = userInfo;
          }
        ) allArchitectures
      ) standalone-user-files
    )
  );
}
