{
  lib,
  inputs,
  build,
  variables,
}:
let
  fragments = import (build + "/builders/fragments.nix") {
    inherit
      lib
      inputs
      build
      variables
      ;
  };
in
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
        home-manager = {
          sharedModules =
            fragments.homeManagerBaseSharedModules
            ++ [ (fragments.mkLixModule pkgs) ]
            ++ lib.optionals (!isNiriDesktop) [ fragments.niriOptionsStub ]
            ++ (
              if !(host.impermanence or false) then
                [
                  (fragments.mkPersistenceDummy {
                    path = "home.persistence";
                    description = "Persistence configuration (dummy for non-impermanent systems)";
                  })
                ]
              else
                [ ]
            );
        }
        // fragments.mkHomeManagerSettings specialArgs;
      }
    ]
    ++ fragments.mkHomeManagerUserModules { inherit buildArgs users; };
}
