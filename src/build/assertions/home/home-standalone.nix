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
      systemProcessedModules = { };
      evaluateModuleAssertions = funcs.evaluateModuleAssertions args "home" {
        systemModules = systemProcessedModules;
        homeModules = processedModules;
      };
    in
    map evaluateModuleAssertions homeModuleAssertions
  );
}
