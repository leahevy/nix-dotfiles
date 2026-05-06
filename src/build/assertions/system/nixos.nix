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
    isVM = config.nx.profile.isVirtual;
    context = "system";
  })
  ++ lib.optionals (host.impermanence or false) (
    let
      allowedSystemPersistPath = variables.persist;
      persistKeys = builtins.attrNames (config.environment.persistence or { });
      invalidKeys = builtins.filter (key: key != allowedSystemPersistPath) persistKeys;

      extractDirList =
        items:
        builtins.map (
          item:
          if builtins.typeOf item == "string" then
            item
          else if builtins.isAttrs item && item ? directory then
            item.directory
          else
            ""
        ) items;

      extractFileList =
        items:
        builtins.map (
          item:
          if builtins.typeOf item == "string" then
            item
          else if builtins.isAttrs item && item ? file then
            item.file
          else
            ""
        ) items;

      systemDirs = lib.concatMap (
        key: extractDirList (config.environment.persistence.${key}.directories or [ ])
      ) persistKeys;

      systemFiles = lib.concatMap (
        key: extractFileList (config.environment.persistence.${key}.files or [ ])
      ) persistKeys;

      invalidSystemDirEntries = builtins.filter (p: p == "" || !(lib.hasPrefix "/" p)) systemDirs;
      invalidSystemFileEntries = builtins.filter (p: p == "" || !(lib.hasPrefix "/" p)) systemFiles;
    in
    [
      {
        assertion =
          lib.hasPrefix "/" allowedSystemPersistPath
          && !(lib.hasSuffix "/" allowedSystemPersistPath)
          && (builtins.match ".*[ ].*" allowedSystemPersistPath) == null;
        message = "variables.persist must start with '/', must not end with '/', and must not contain spaces!";
      }
      {
        assertion = invalidKeys == [ ];
        message = "environment.persistence contains invalid mount points: ${builtins.concatStringsSep ", " invalidKeys}. Only '${allowedSystemPersistPath}' is allowed (use self.persist).";
      }
      {
        assertion = invalidSystemDirEntries == [ ];
        message = "environment.persistence directories must be absolute paths starting with '/'!";
      }
      {
        assertion = invalidSystemFileEntries == [ ];
        message = "environment.persistence files must be absolute paths starting with '/'!";
      }
    ]
  )
  ++ [
    {
      assertion = (config.disko.devices or { }) == { } -> config.nx.profile.isVirtual;
      message = "Disko devices not found on a physical machine! (File disk.nix in nixos profile folder)";
    }
    {
      assertion = host.remote.buildUser != "";
      message = "host.remote.buildUser must not be empty!";
    }
    {
      assertion = (builtins.match ".*[@ ].*" host.remote.buildUser) == null;
      message = "host.remote.buildUser must not contain '@' or spaces!";
    }
    {
      assertion =
        host.remote.address == null
        || (builtins.match ".*[;&|`<>$(){}!\"'\\\\ ].*" host.remote.address) == null;
      message = "host.remote.address must not contain unsafe characters!";
    }
    {
      assertion =
        host.remote.buildIdentityFile != null
        -> (builtins.match ".*[;&|`<>$(){}!\"'\\\\ ].*" host.remote.buildIdentityFile) == null;
      message = "host.remote.buildIdentityFile must not contain spaces or unsafe characters!";
    }
    {
      assertion =
        let
          remote = host.remote;
        in
        (
          remote.buildIdentityFile != null
          || remote.buildPublicSSHKey != null
          || remote.address != null
          || (remote.buildUser != null && remote.buildUser != "root")
        )
        -> (
          remote.buildIdentityFile != null
          && remote.buildPublicSSHKey != null
          && remote.address != null
          && remote.buildUser != null
        );
      message = "All host.remote settings must be provided if any of them is provided!";
    }
    {
      assertion =
        (host.remote.address != null && !host.remote.allowLuksRootEncryption)
        -> (config.boot.initrd.luks.devices or { }) == { };
      message = "Host is not configured to use LUKS root encryption (via remote settings), but it has been enabled in the initrd!";
    }
    {
      assertion =
        let
          buildUser = host.remote.buildUser;
          users = config.users.users;
        in
        (buildUser != null && buildUser != "root")
        -> (
          (builtins.hasAttr buildUser users)
          && (users.${buildUser}.isNormalUser || users.${buildUser}.isSystemUser)
          && (users.${buildUser}.group != null && users.${buildUser}.group != "")
        );
      message = "Host has configured ${host.remote.buildUser} as buildUser, but this user does not exist in the configuration!";
    }
  ];
}
