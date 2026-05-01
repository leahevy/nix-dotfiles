args@{
  lib,
  funcs,
  helpers,
  defs,
  host,
  variables,
  processedModules,
  ...
}:
{ config, ... }:
let
  moduleInputs = helpers.allModuleInputsToScan;

  countEnabledModules = lib.pipe moduleInputs [
    (map (
      inputName:
      lib.mapAttrsToList (
        groupName: groupModules:
        if !builtins.isAttrs groupModules then
          [ ]
        else
          lib.mapAttrsToList (
            moduleName: moduleConfig:
            if (config.nx.${inputName}.${groupName}.${moduleName}.enable or false) then 1 else 0
          ) groupModules
      ) (config.nx.${inputName} or { })
    ))
    lib.flatten
    (builtins.foldl' builtins.add 0)
  ];
in
{
  assertions = [
    {
      assertion = countEnabledModules >= config.nx.global.minEnabledModules;
      message = "Only ${toString countEnabledModules} modules enabled, but at least ${toString config.nx.global.minEnabledModules} required for configuration integrity";
    }
    {
      assertion = builtins.match "^[0-9]+[MG]$" host.settings.system.tmpSize != null;
      message = "host.settings.system.tmpSize must be in format '{number}M' or '{number}G' (e.g., '4G', '512M')";
    }
    {
      assertion = builtins.isAttrs host.mainUser;
      message = "host.mainUser must be an attribute set (processed config) at assertion time";
    }
    {
      assertion = builtins.all builtins.isAttrs host.additionalUsers;
      message = "All host.additionalUsers must be attribute sets (processed configs) at assertion time";
    }
    (funcs.validateUnfreePackages {
      packages = config.environment.systemPackages or [ ];
      declaredUnfree = (host.allowedUnfreePackages or [ ]) ++ (variables.allowedUnfreePackages or [ ]);
      context = "system";
      profileName = host.profileName or "unknown";
      processedModules = processedModules;
    })
  ]
  ++ helpers.assertNotNull "host" host [
    "hostname"
    "mainUser"
  ]
  ++ (
    let
      systemModuleAssertions = funcs.collectModuleAssertions args processedModules;
      evaluateModuleAssertions = funcs.evaluateModuleAssertions args {
        processedModules = processedModules;
      };
    in
    map evaluateModuleAssertions systemModuleAssertions
  )
  ++ (helpers.validateSystemdReferences {
    inherit host;
    config = config;
    architecture = host.architecture;
    isVM = config.nx.profile.isVirtual || (host.isVM or false);
    context = "system";
  })
  ++ lib.optionals (host.impermanence or false) (
    let
      allowedSystemPersistPath = variables.persist;
      persistKeys = builtins.attrNames (config.environment.persistence or { });
      invalidKeys = builtins.filter (key: key != allowedSystemPersistPath) persistKeys;
    in
    [
      {
        assertion = invalidKeys == [ ];
        message = "environment.persistence contains invalid mount points: ${builtins.concatStringsSep ", " invalidKeys}. Only '${allowedSystemPersistPath}' is allowed (use self.persist).";
      }
    ]
  )
  ++ [
    {
      assertion = (config.disko.devices or { }) == { } -> config.nx.profile.isVirtual;
      message = "Disko devices not found on a physical machine! (File disk.nix in nixos profile folder)";
    }
  ];
}
