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

{
  assertions = [
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
      systemModuleAssertions = funcs.collectModuleAssertions args processedModules "system";
      homeProcessedModules = args.homeProcessedModules or { };
      evaluateModuleAssertions = funcs.evaluateModuleAssertions args "system" {
        systemModules = processedModules;
        homeModules = homeProcessedModules;
      };
    in
    map evaluateModuleAssertions systemModuleAssertions
  );
}
