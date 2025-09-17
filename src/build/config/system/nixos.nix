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
  ...
}:

let
  buildModules = {
    build = {
      core = {
        boot = true;
        sudo = true;
        i18n = true;
        network = true;
        users = true;
        nix-ld = true;
        tokens = true;
        sops = true;
      };
      desktop = {
        desktop = true;
        sound = true;
      };
      programs = {
        programs = true;
      };
      system = { } // (if host.impermanence or false then { impermanence = true; } else { });
    };
  };

  initialModules = lib.recursiveUpdate (ifSet host.modules { }) buildModules;
  allModules = funcs.collectAllModulesWithSettings args initialModules "system";

  moduleSpecs = funcs.processModules allModules;
  moduleResults = funcs.importSystemModules args moduleSpecs;

  extraModules = moduleResults.modules;

  specialisationConfigs =
    builtins.mapAttrs (specName: specModules: {
      configuration = {
        imports = (funcs.importSystemModules args (funcs.processModules specModules)).modules;
      };
    }) host.specialisations
    // {
      Base = {
        configuration = { };
      };
    };

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
      (import ../../assertions/system/nixos.nix (args // { processedModules = allModules; }))
    ];

  config = lib.mkMerge [
    {
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
        };
      };
    }

    (lib.mkIf (config.specialisation != { }) (
      if host.defaultSpecialisation == "Base" then
        { }
      else if builtins.hasAttr host.defaultSpecialisation host.specialisations then
        lib.mkMerge (
          map (spec: (funcs.importSystemModule args spec) { inherit config options; }) (
            funcs.processModules host.specialisations.${host.defaultSpecialisation}
          )
        )
      else
        throw "defaultSpecialisation '${host.defaultSpecialisation}' does not exist in host.specialisations. Available specialisations: ${builtins.toString (builtins.attrNames host.specialisations)}"
    ))
  ];
}
