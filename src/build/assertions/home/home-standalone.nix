args@{
  lib,
  funcs,
  helpers,
  defs,
  user,
  variables,
  processedModules,
  ...
}:
{ config, ... }:
{
  assertions = [
    {
      assertion =
        (user.deploymentMode or "develop") == "local" || (user.deploymentMode or "develop") == "develop";
      message = "Standalone Home Manager profiles only support deploymentMode local or develop!";
    }
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
      assertion = user.settings.desktop == null || user.settings.terminal != null;
      message = "If desktop environment is configured, terminal must also be configured in user.settings.terminal.";
    }
  ]
  ++ (helpers.validateSystemdReferences {
    config = config;
    architecture = user.architecture;
    context = "user";
  });
}
