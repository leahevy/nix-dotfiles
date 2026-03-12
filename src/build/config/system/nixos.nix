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

  allOptionsData = funcs.collectAllModuleOptions systemArgs;
  optionsModules = funcs.generateOptionsModules allOptionsData;

  initModules = funcs.importAllModuleInits systemArgs;

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

  profileInitModules =
    let
      hostInit =
        if host.init != (args: context: { }) then
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
          [ (host.init enhancedArgs) ]
        else
          [ ];
      userInit =
        if host.mainUser.init != (args: context: { }) then
          let
            moduleContext = {
              inputs = inputs;
              variables = variables;
              configInputs = args.configInputs or { };
              moduleBasePath = "profiles/home-integrated/${host.mainUser.profileName}";
              moduleInput = args.configInputs.config or inputs.config;
              moduleInputName = "config";
              user = host.mainUser;
              host = host;
              persist = "${variables.persist.home}/${host.mainUser.username}";
            };
            enhancedContext = funcs.injectModuleFuncs moduleContext "home";
            enhancedArgs = args // {
              self = enhancedContext;
            };
          in
          [ (host.mainUser.init enhancedArgs) ]
        else
          [ ];
    in
    hostInit ++ userInit;
in
{ config, options, ... }:
{
  imports =
    optionsModules
    ++ initModules
    ++ profileInitModules
    ++ extraModules
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
