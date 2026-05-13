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
      assertion =
        let
          remoteEnabled = user.settings.hasRemoteCommand or false;
        in
        (!remoteEnabled) || (variables.isoManagementSSHKey or null) != null;
      message = "Remote command is enabled but variables.isoManagementSSHKey is not set!";
    }
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
    {
      assertion =
        user.defaultSSHKey == null
        || builtins.hasAttr user.defaultSSHKey config.nx.common.services.ssh.keys;
      message = "user.defaultSSHKey '${toString user.defaultSSHKey}' not found in nx.common.services.ssh.keys!";
    }
  ]
  ++ helpers.assertNotNull "user" user [
    "username"
    "fullname"
    "email"
    "home"
  ];
}
