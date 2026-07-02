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
    forEachProfileAndArch
    ;

  fragments = import (build + "/builders/fragments.nix") {
    inherit
      lib
      inputs
      build
      variables
      ;
  };

  buildHomeConfiguration =
    {
      profileName,
      arch,
      buildArch ? arch,
    }:
    let
      processResult = processStandaloneUserProfile { inherit profileName arch buildArch; };
      inherit (processResult) userConfig buildContext;
      inherit (buildContext)
        pkgs
        lib
        buildArgs
        extraUserModule
        ;

      isNiriDesktop = userConfig.settings.desktop == "niri";
    in
    {
      name =
        if buildArch == arch then "${profileName}--${arch}" else "${profileName}--${arch}--${buildArch}";
      value = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          (import (build + "/config/home/home-standalone.nix") buildArgs)
          (fragments.mkLixModule pkgs)
          inputs.sops-nix.homeManagerModules.sops
          inputs.stylix.homeModules.stylix
          inputs.nixvim.homeModules.nixvim
          inputs.nix-index-database.homeModules.default
        ]
        ++ (lib.optionals (helpers.isLinuxArch arch && isNiriDesktop) [
          inputs.niri-flake.homeModules.niri
          inputs.niri-flake.homeModules.stylix
          {
            programs.niri.package = lib.mkDefault pkgs.niri;
          }
        ])
        ++ (lib.optionals (helpers.isDarwinArch arch || !isNiriDesktop) [
          (
            fragments.niriOptionsStub
            // {
              config.lib.niri.actions.spawn = _: null;
              config.lib.niri.actions.spawn-sh = _: null;
            }
          )
        ])
        ++ [
          (fragments.mkPersistenceDummy {
            path = "home.persistence";
            description = "Persistence configuration (stub for standalone Home Manager)";
          })
        ]
        ++ extraUserModule
        ++ lib.optionals (helpers.isDarwinArch arch) [
          inputs.mac-app-util.homeManagerModules.default
          inputs.nix-plist-manager.homeManagerModules.default
        ];
      };
    };

in

{
  buildHomeConfigurations =
    forEachProfileAndArch allArchitectures standalone-user-files
      buildHomeConfiguration;

}
