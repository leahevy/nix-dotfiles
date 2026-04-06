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
  processedModules,
  ...
}:

let
  allModules = processedModules;

  moduleSpecs = funcs.processModules allModules;
  systemArgs = args // {
    user = host.mainUser;
    processedModules = allModules;
  };
  moduleResults = funcs.importModules systemArgs moduleSpecs allModules "system";

  extraModules = moduleResults.modules;

  allModuleData = funcs.collectAllModuleData systemArgs;
  optionsModules = funcs.generateOptionsModules allModuleData;
  settingsValueModules = funcs.generateSettingsValueModules allModuleData allModules;
  optionsValueModules = funcs.generateOptionsValueModules allModuleData allModules;
  enableValueModules = funcs.generateEnableValueModules allModuleData allModules;
  metaValueModules = funcs.generateMetaValueModules allModuleData;

  initModules = funcs.importAllModuleInits systemArgs;

  specialisationConfigs = builtins.mapAttrs (specName: specModules: {
    configuration = {
      imports =
        (funcs.importModules systemArgs (funcs.processModules specModules) allModules "system").modules;
    };
  }) host.specialisations;

  ifSet = helpers.ifSet;

  hostProfileOn = funcs.processProfileOn {
    profile = host;
    profileType = "nixos";
    profileName = host.profileName;
    args = systemArgs;
    processedModules = allModules;
    buildContext = "system";
  };

  userProfileOn = funcs.processProfileOn {
    profile = host.mainUser;
    profileType = "home-integrated";
    profileName = host.mainUser.profileName;
    args = systemArgs;
    processedModules = allModules;
    buildContext = "system";
  };

  profileInitModules = hostProfileOn.initModules ++ userProfileOn.initModules;
  profileContextModules = hostProfileOn.contextModules ++ userProfileOn.contextModules;
in
{ config, options, ... }:
{
  imports =
    optionsModules
    ++ settingsValueModules
    ++ optionsValueModules
    ++ enableValueModules
    ++ metaValueModules
    ++ initModules
    ++ profileInitModules
    ++ extraModules
    ++ profileContextModules
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
