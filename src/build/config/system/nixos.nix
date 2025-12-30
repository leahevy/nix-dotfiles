args@{
  lib,
  pkgs,
  pkgs-unstable,
  inputs,
  host,
  users,
  funcs,
  helpers,
  defs,
  variables,
  systemProcessedModules,
  homeProcessedModules,
  ...
}:

let
  allModules = systemProcessedModules;
  mainUserModules = homeProcessedModules;

  moduleSpecs = funcs.processModules allModules;
  systemArgs = args // {
    user = host.mainUser;
    homeProcessedModules = mainUserModules;
  };
  moduleResults = funcs.importSystemModules systemArgs moduleSpecs allModules;

  extraModules = moduleResults.modules;

  specialisationConfigs = builtins.mapAttrs (specName: specModules: {
    configuration = {
      imports =
        (funcs.importSystemModules systemArgs (funcs.processModules specModules) allModules).modules;
    };
  }) host.specialisations;

  ifSet = helpers.ifSet;

  virtualModule =
    if host.configuration != (args: context: { }) then
      let
        moduleContext = {
          inputs = inputs;
          variables = variables;
          configInputs = args.configInputs or { };
          moduleBasePath = "profiles/nixos/${host.profileName}";
          moduleInput = args.configInputs.config or inputs.config;
          moduleInputName = "config";
          host = host;
          users = users;
          persist = variables.persist.system;
        };

        enhancedContext = funcs.injectModuleFuncs moduleContext "system";

        enhancedArgs = args // {
          self = enhancedContext;
        };
      in
      [ (host.configuration enhancedArgs) ]
    else
      [ ];
in
{ config, options, ... }:
{
  imports =
    extraModules
    ++ virtualModule
    ++ [
      (import ../../assertions/system/nixos.nix (systemArgs // { processedModules = allModules; }))
    ];

  config = {
    specialisation = specialisationConfigs;

    environment = {
      systemPackages = host.additionalPackages or [ ];
    };

    system.stateVersion =
      if host.stateVersion != null then host.stateVersion else variables.state-version;

    nixpkgs.hostPlatform = host.architecture;

    nix = {
      settings = {
        experimental-features = variables.experimental-features;
        trusted-users = [ host.mainUser.username ];
        http-connections = variables.httpConnections;
        keep-outputs = true;
        keep-derivations = true;
      };
    };
  };
}
