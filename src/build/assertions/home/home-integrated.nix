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

{
  assertions = [
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
      homeModuleAssertions = funcs.collectModuleAssertions args processedModules "home";
      systemProcessedModules = args.systemProcessedModules or { };
      evaluateModuleAssertions = funcs.evaluateModuleAssertions args "home" {
        systemModules = systemProcessedModules;
        homeModules = processedModules;
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
  });
}
