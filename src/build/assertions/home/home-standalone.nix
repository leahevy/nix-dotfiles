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
  })
  ++ (
    let
      allowedHomePersistPath = "${variables.persist.home}/${user.username}";
      persistKeys = builtins.attrNames (config.home.persistence or { });
      invalidKeys = builtins.filter (key: key != allowedHomePersistPath) persistKeys;
    in
    [
      {
        assertion = invalidKeys == [ ];
        message = "home.persistence contains invalid mount points: ${builtins.concatStringsSep ", " invalidKeys}. Only '${allowedHomePersistPath}' is allowed (use self.persist.home).";
      }
    ]
  );
}
