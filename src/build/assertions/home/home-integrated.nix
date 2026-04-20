args@{
  lib,
  funcs,
  helpers,
  defs,
  user,
  host,
  variables,
  processedModules,
  ...
}:
{ config, osConfig, ... }:
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
    (funcs.validateUnfreePackages {
      packages = config.home.packages or [ ];
      declaredUnfree = (user.allowedUnfreePackages or [ ]) ++ (variables.allowedUnfreePackages or [ ]);
      context = "home";
      profileName = user.profileName or "unknown";
      processedModules = processedModules;
    })
  ]
  ++ helpers.assertNotNull "user" user [
    "username"
    "fullname"
    "email"
    "home"
  ]
  ++ (
    let
      homeModuleAssertions = funcs.collectModuleAssertions args processedModules;
      evaluateModuleAssertions = funcs.evaluateModuleAssertions args {
        processedModules = processedModules;
      };
    in
    map evaluateModuleAssertions homeModuleAssertions
  )
  ++ [
    {
      assertion = host.settings.system.desktop == null || user.settings.terminal != null;
      message = "If desktop environment is configured, terminal must also be configured in user.settings.terminal.";
    }
  ]
  ++ (helpers.validateSystemdReferences {
    config = config;
    architecture = user.architecture;
    context = "user";
    osConfig = osConfig;
  })
  ++ lib.optionals (host.impermanence or false) (
    let
      allowedHomePersistPath = "${variables.persist}";
      persistKeys = builtins.attrNames (config.home.persistence or { });
      invalidKeys = builtins.filter (key: key != allowedHomePersistPath) persistKeys;
    in
    [
      {
        assertion = invalidKeys == [ ];
        message = "home.persistence contains invalid mount points: ${builtins.concatStringsSep ", " invalidKeys}. Only '${allowedHomePersistPath}' is allowed (use self.persist).";
      }
    ]
  );
}
