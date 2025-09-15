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
  ];
}
