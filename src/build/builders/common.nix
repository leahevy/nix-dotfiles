{
  lib,
  inputs,
  config,
  build,
  variables,
  helpers,
  defs,
  funcs,
  additionalInputs,
  host-files,
  standalone-user-files,
  integrated-user-files,
  nixosArchitectures,
  darwinArchitectures,
  allArchitectures,
}:

let
  makeFuncs =
    profilePath:
    import (additionalInputs.lib + "/funcs.nix") {
      inherit lib defs;
      additionalInputs = additionalInputs // {
        profile = profilePath;
      };
    };

  mkProfileSelf =
    profileType: profileName: extraContext:
    funcs.injectModuleFuncs (
      {
        inputs = inputs // {
          profile = config + "/profiles/${profileType}/${profileName}";
        };
        inherit variables;
        configInputs = { };
        nixOSHosts = { };
        homeIntegratedUsers = { };
        homeStandaloneUsers = { };
        moduleBasePath = "profiles/${profileType}/${profileName}/";
        moduleInput = config;
        moduleInputName = "config";
        host = { };
        user = null;
        users = { };
        processedModules = builtins.throw "self.isModuleEnabled and related functions cannot be used in profile outer scope!";
        isTestingVM = false;
        isProductionVM = false;
        isVirtual = false;
      }
      // extraContext
    );

  evalConfigModule =
    {
      configPath,
      optionPaths,
      specialArgs ? { },
    }:
    let
      mergedOptionsModule =
        args:
        let
          raw = lib.foldl lib.recursiveUpdate { } (map (path: import path args) optionPaths);
          allOpts = raw.options.all or { };
          mainOpts = raw.options.main or { };
          relocated = lib.recursiveUpdate allOpts mainOpts;
          baseOptions = removeAttrs raw.options [
            "all"
            "main"
          ];
          target = if baseOptions ? host then "host" else "user";
          targetOptions = baseOptions.${target} or { };
        in
        raw
        // {
          options = baseOptions // {
            ${target} = lib.recursiveUpdate relocated targetOptions;
          };
        };
    in
    inputs.nixpkgs.lib.evalModules {
      modules = [
        mergedOptionsModule
        configPath
      ];
      inherit specialArgs;
    };

  setupPackages =
    {
      system,
      extraOverlays ? [ ],
      allowedUnfreePackages ? null,
      nixpkgs ? inputs.nixpkgs,
      nixpkgs-unstable ? inputs.nixpkgs-unstable,
      nixpkgs-darwin ? inputs.nixpkgs-darwin,
      nixpkgs-nix ? inputs.nixpkgs-nix,
    }:
    let
      moduleOverlays = funcs.collectModuleOverlays system variables;
      packageFuncsModule = import (additionalInputs.lib + "/packageFuncs.nix") {
        inherit defs additionalInputs helpers;
      };
      packageFuncsOverlay = final: prev: packageFuncsModule final;
      overlays = moduleOverlays ++ extraOverlays ++ [ packageFuncsOverlay ];

      unfreePredicate =
        if allowedUnfreePackages == null then
          pkg: true
        else
          pkg: lib.elem (lib.getName pkg) allowedUnfreePackages;

      pkgs-unstable = import nixpkgs-unstable {
        inherit system overlays;
        config = {
          allowUnfreePredicate = unfreePredicate;
          permittedInsecurePackages = variables.releaseTransitionInsecurePackages or [ ];
        };
      };

      unstablePackages =
        variables.unstablePackages
        ++ lib.optionals (helpers.isLinuxArch system) variables.unstableLinuxPackages
        ++ lib.optionals (helpers.isDarwinArch system) variables.unstableDarwinPackages;

      unstableOverrides = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = pkgs-unstable.${name};
        }) unstablePackages
      );

      nixImpl = variables."nix-implementation";

      pkgs-nix = import nixpkgs-nix {
        inherit system;
        config = {
          allowUnfreePredicate = unfreePredicate;
          permittedInsecurePackages = variables.releaseTransitionInsecurePackages or [ ];
        };
      };

      nixImplOverlay =
        if nixImpl == "nix" then
          (final: prev: {
            inherit (pkgs-nix)
              nix
              nix-cmd
              nix-expr
              nix-fetchers
              nix-flake
              nix-main
              nix-store
              nix-util
              ;
          })
        else if nixImpl == "lix" then
          (final: prev: {
            lixPackageSets = pkgs-nix.lixPackageSets;
            inherit (pkgs-nix)
              nix
              nix-cmd
              nix-expr
              nix-fetchers
              nix-flake
              nix-main
              nix-store
              nix-util
              ;
            inherit (pkgs-nix.lixPackageSets.stable)
              lix
              nixpkgs-review
              nix-eval-jobs
              nix-fast-build
              colmena
              ;
          })
        else
          throw "setupPackages: unknown nix-implementation '${nixImpl}', must be 'nix' or 'lix'";

      nixToolsOverlay = (
        final: prev: {
          inherit (pkgs-nix)
            nix-diff
            nix-search-tv
            nix-search
            nix-index
            nh
            ;
        }
      );

      allOverlays = overlays ++ [
        (final: prev: unstableOverrides)
        nixImplOverlay
        nixToolsOverlay
        (final: prev: { unstable = pkgs-unstable; })
      ];

      buildPkgs =
        nixpkgs:
        import nixpkgs {
          inherit system;
          overlays = allOverlays;
          config = {
            allowUnfreePredicate = unfreePredicate;
            permittedInsecurePackages = variables.releaseTransitionInsecurePackages or [ ];
          };
        };

      pkgs =
        if helpers.isLinuxArch system then
          buildPkgs nixpkgs
        else if helpers.isDarwinArch system then
          buildPkgs nixpkgs-darwin
        else
          throw "builder: cannot determine system architecture!";
    in
    {
      inherit
        pkgs
        pkgs-unstable
        allOverlays
        unfreePredicate
        ;
    };

  getHardwareModule =
    { host, isPhysical }:
    if host.nixHardwareModule != null && isPhysical then
      [ (inputs.nixos-hardware + "/${host.nixHardwareModule}") ]
    else
      [ ];

  getDiskoModule =
    { profileName }:
    let
      diskoPath = config + "/profiles/nixos/${profileName}/disk.nix";
    in
    [ inputs.disko.nixosModules.disko ] ++ lib.optional (builtins.pathExists diskoPath) diskoPath;

  resolveHomePath =
    { user, arch }:
    if (user.home or null) == null then
      if helpers.isLinuxArch arch then
        "/home/${user.username}"
      else if helpers.isDarwinArch arch then
        "/Users/${user.username}"
      else
        user.home
    else
      user.home;

  enrichUserProfile =
    rawUser: profileName: isStandalone: isMainUser: arch:
    rawUser
    // {
      inherit profileName;
      inherit isStandalone;
      isIntegrated = !isStandalone;
      isMainUser = isMainUser;
      architecture = arch;
      home = resolveHomePath {
        user = rawUser;
        inherit arch;
      };
    };

  buildSpecialArgs =
    {
      pkgs,
      host ? { },
      users ? { },
      user ? { },
      configInputs ? { },
      helpers ? helpers,
      nixOSHosts ? { },
      homeIntegratedUsers ? { },
      homeStandaloneUsers ? { },
    }:
    {
      inherit inputs;
      inherit variables;
      inherit funcs;
      inherit helpers;
      inherit defs;
      inherit configInputs;
      inherit nixOSHosts;
      inherit homeIntegratedUsers;
      inherit homeStandaloneUsers;
    }
    // lib.optionalAttrs (host != { }) { inherit host; }
    // lib.optionalAttrs (users != { }) { inherit users; }
    // lib.optionalAttrs (user != { }) { inherit user; };

  evalNixOSHosts =
    {
      pkgs,
      pkgs-unstable,
    }:
    builtins.listToAttrs (
      map (
        profileName:
        let
          hostConfigPath = config + "/profiles/nixos/${profileName}/${profileName}.nix";
          r = evalConfigModule {
            optionPaths = [
              (build + "/types/shared/all.nix")
              (build + "/types/shared/main.nix")
              (build + "/types/system/nixos.nix")
            ];
            configPath = hostConfigPath;
            specialArgs = {
              inherit
                lib
                variables
                helpers
                defs
                pkgs
                pkgs-unstable
                ;
              self = mkProfileSelf "nixos" profileName { };
            };
          };
        in
        {
          name = profileName;
          value = r.config.host // {
            inherit profileName;
          };
        }
      ) host-files
    );

  evalHomeIntegratedUsers =
    {
      pkgs,
      pkgs-unstable,
    }:
    builtins.listToAttrs (
      map (
        profileName:
        let
          userConfigPath = config + "/profiles/home-integrated/${profileName}/${profileName}.nix";
          r = evalConfigModule {
            optionPaths = [
              (build + "/types/shared/all.nix")
              (build + "/types/shared/user.nix")
              (build + "/types/home/home-integrated.nix")
            ];
            configPath = userConfigPath;
            specialArgs = {
              inherit
                lib
                variables
                helpers
                defs
                pkgs
                pkgs-unstable
                ;
              self = mkProfileSelf "home-integrated" profileName { };
            };
          };
        in
        {
          name = profileName;
          value = r.config.user // {
            inherit profileName;
          };
        }
      ) integrated-user-files
    );

  evalHomeStandaloneUsers =
    {
      pkgs,
      pkgs-unstable,
    }:
    builtins.listToAttrs (
      map (
        profileName:
        let
          userConfigPath = config + "/profiles/home-standalone/${profileName}/${profileName}.nix";
          r = evalConfigModule {
            optionPaths = [
              (build + "/types/shared/all.nix")
              (build + "/types/shared/user.nix")
              (build + "/types/shared/main.nix")
              (build + "/types/home/home-standalone.nix")
            ];
            configPath = userConfigPath;
            specialArgs = {
              inherit
                lib
                variables
                helpers
                defs
                pkgs
                pkgs-unstable
                ;
              self = mkProfileSelf "home-standalone" profileName { };
            };
          };
        in
        {
          name = profileName;
          value = r.config.user // {
            inherit profileName;
          };
        }
      ) standalone-user-files
    );

  evalAllProfiles =
    {
      pkgs,
      pkgs-unstable,
    }:
    let
      rawNixOSHosts = evalNixOSHosts { inherit pkgs pkgs-unstable; };
      homeIntegratedUsers = evalHomeIntegratedUsers { inherit pkgs pkgs-unstable; };
      homeStandaloneUsers = evalHomeStandaloneUsers { inherit pkgs pkgs-unstable; };
      nixOSHosts = builtins.mapAttrs (
        _n: h:
        h
        // {
          mainUser =
            if h.mainUser == null then
              throw "NixOS profile '${h.profileName}' has mainUser = null but a valid home-integrated user is required!"
            else if !builtins.isString h.mainUser then
              throw "NixOS profile '${h.profileName}': mainUser must be a profile name (string) in profile files!"
            else if builtins.hasAttr h.mainUser homeIntegratedUsers then
              homeIntegratedUsers.${h.mainUser}
            else
              throw "NixOS profile '${h.profileName}' references mainUser '${h.mainUser}' but no matching home-integrated profile exists!";
        }
      ) rawNixOSHosts;
    in
    {
      inherit nixOSHosts homeIntegratedUsers homeStandaloneUsers;
    };
in

{
  inherit
    evalConfigModule
    setupPackages
    buildSpecialArgs
    getHardwareModule
    getDiskoModule
    ;

  generateNixOSProfiles =
    profileNames:
    lib.flatten (
      map (
        profileName:
        map (arch: {
          name = "${profileName}--${arch}";
          profileName = profileName;
          architecture = arch;
        }) nixosArchitectures
      ) profileNames
    );

  generateHomeStandaloneProfiles =
    profileNames:
    lib.flatten (
      map (
        profileName:
        map (arch: {
          name = "${profileName}--${arch}";
          profileName = profileName;
          architecture = arch;
        }) allArchitectures
      ) profileNames
    );

  processHostProfile =
    {
      profileName,
      arch,
      buildArch ? arch,
      overrides ? { },
      isTestingVM ? false,
      isProductionVM ? false,
    }:
    let
      localHelpers = helpers // {
        isHostArchitecture = arch == buildArch;
      };
      funcs = makeFuncs (config + "/profiles/nixos/${profileName}");
      hostConfigPath = config + "/profiles/nixos/${profileName}/${profileName}.nix";

      system = arch;

      preEval = evalConfigModule {
        optionPaths = [
          (build + "/types/shared/all.nix")
          (build + "/types/shared/main.nix")
          (build + "/types/system/nixos.nix")
        ];
        configPath = hostConfigPath;
        specialArgs = {
          inherit
            lib
            variables
            helpers
            defs
            ;
          pkgs = { };
          pkgs-unstable = { };
          self = mkProfileSelf "nixos" profileName { };
        };
      };
      profileOverlays = funcs.extractOverlaysFromModule {
        module = preEval.config.host.module or { };
        inherit system variables;
      };

      mainUserProfileName = preEval.config.host.mainUser;
      mainUserConfigPath =
        config + "/profiles/home-integrated/${mainUserProfileName}/${mainUserProfileName}.nix";

      mainUserPreEval =
        if builtins.isString mainUserProfileName && builtins.pathExists mainUserConfigPath then
          let
            evalResult = builtins.tryEval (evalConfigModule {
              optionPaths = [
                (build + "/types/shared/all.nix")
                (build + "/types/shared/user.nix")
                (build + "/types/home/home-integrated.nix")
              ];
              configPath = mainUserConfigPath;
              specialArgs = {
                inherit
                  lib
                  variables
                  helpers
                  defs
                  ;
                pkgs = { };
                pkgs-unstable = { };
                self = mkProfileSelf "home-integrated" mainUserProfileName { };
              };
            });
          in
          if evalResult.success then evalResult.value else null
        else
          null;

      mainUserAllowedUnfree =
        if mainUserPreEval != null then mainUserPreEval.config.user.allowedUnfreePackages or [ ] else [ ];

      preMergedModules = funcs.mergeModulesWithPrecedence (preEval.config.host.modules or { }) (
        lib.foldl lib.recursiveUpdate { } [
          (if mainUserPreEval != null then mainUserPreEval.config.user.modules or { } else { })
          (preEval.config.host.userDefaults.modules or { })
        ]
      );

      preBuildModules = funcs.computeNixOSBuildModules {
        addHostBaseGroup = preEval.config.host.addBaseGroup or false;
        addUserBaseGroup =
          if mainUserPreEval != null then mainUserPreEval.config.user.addBaseGroup or false else false;
        desktop = preEval.config.host.settings.system.desktop or null;
      };

      preEvalHost = preEval.config.host // {
        architecture = arch;
        inherit profileName;
      };
      preEvalMainUser =
        if mainUserPreEval != null then
          enrichUserProfile mainUserPreEval.config.user mainUserProfileName false true arch
        else
          null;

      allowedUnfreePackages = lib.unique (
        (variables.allowedUnfreePackages or [ ])
        ++ (preEval.config.host.allowedUnfreePackages or [ ])
        ++ mainUserAllowedUnfree
        ++
          funcs.collectAllModuleUnfreePackages system preMergedModules preBuildModules preEvalHost
            preEvalMainUser
            variables
            inputs
      );

      inherit
        (setupPackages {
          inherit system allowedUnfreePackages;
          extraOverlays = profileOverlays;
        })
        pkgs
        pkgs-unstable
        allOverlays
        unfreePredicate
        ;

      hostEval = evalConfigModule {
        optionPaths = [
          (build + "/types/shared/all.nix")
          (build + "/types/shared/main.nix")
          (build + "/types/system/nixos.nix")
        ];
        configPath = hostConfigPath;
        specialArgs = {
          inherit
            lib
            variables
            helpers
            defs
            pkgs
            pkgs-unstable
            ;
          self = mkProfileSelf "nixos" profileName {
            inherit nixOSHosts homeIntegratedUsers homeStandaloneUsers;
          };
        };
      };

      rawHost = hostEval.config.host // {
        architecture = arch;
        isNixOS = true;
        isDarwin = false;
      };

      evalIntegratedUser =
        userProfileName:
        let
          userConfigPath = config + "/profiles/home-integrated/${userProfileName}/${userProfileName}.nix";

          userEval = evalConfigModule {
            optionPaths = [
              (build + "/types/shared/all.nix")
              (build + "/types/shared/user.nix")
              (build + "/types/home/home-integrated.nix")
            ];
            configPath = userConfigPath;
            specialArgs = {
              inherit
                lib
                variables
                helpers
                defs
                pkgs
                pkgs-unstable
                ;
              self = mkProfileSelf "home-integrated" userProfileName {
                inherit nixOSHosts homeIntegratedUsers homeStandaloneUsers;
              };
            };
          };
        in
        enrichUserProfile userEval.config.user userProfileName false (
          userProfileName == rawHost.mainUser
        ) arch;

      allUserProfiles = [ rawHost.mainUser ] ++ (rawHost.additionalUsers or [ ]);
      userAttrSet = builtins.listToAttrs (
        map (
          userProfileName:
          let
            user = evalIntegratedUser userProfileName;
          in
          {
            name = user.username;
            value = user;
          }
        ) allUserProfiles
      );

      mainUser =
        userAttrSet.${
          (builtins.head (builtins.filter (u: u.isMainUser) (builtins.attrValues userAttrSet))).username
        };
      additionalUsers = builtins.filter (u: !u.isMainUser) (builtins.attrValues userAttrSet);

      resolvedHost = lib.recursiveUpdate (
        rawHost
        // {
          inherit profileName;
          mainUser = mainUser;
          additionalUsers = additionalUsers;
        }
      ) overrides;

      mergedModules = funcs.mergeModulesWithPrecedence (helpers.ifSet (rawHost.modules or { }) { }) (
        lib.foldl lib.recursiveUpdate { } [
          (mainUser.modules or { })
          (rawHost.userDefaults.modules or { })
        ]
      );

      buildModules = funcs.computeNixOSBuildModules {
        addHostBaseGroup = resolvedHost.addBaseGroup;
        addUserBaseGroup = mainUser.addBaseGroup;
        desktop = resolvedHost.settings.system.desktop;
      };

      effectiveIsTestingVM = isTestingVM;
      effectiveIsProductionVM =
        if effectiveIsTestingVM then false else isProductionVM || (resolvedHost.isVM or false);
      effectiveIsVirtual = effectiveIsTestingVM || effectiveIsProductionVM;

      inherit (evalAllProfiles { inherit pkgs pkgs-unstable; })
        nixOSHosts
        homeIntegratedUsers
        homeStandaloneUsers
        ;

      unifiedArgs = {
        inherit
          lib
          pkgs
          inputs
          variables
          defs
          funcs
          effectiveIsTestingVM
          effectiveIsProductionVM
          effectiveIsVirtual
          nixOSHosts
          homeIntegratedUsers
          homeStandaloneUsers
          ;
        helpers = localHelpers;
        host = resolvedHost;
        user = mainUser;
        users = userAttrSet;
        configInputs = config.configInputs or { };
      };
      unifiedArgsWithVmState = unifiedArgs // {
        isTestingVM = effectiveIsTestingVM;
        isProductionVM = effectiveIsProductionVM;
        isVirtual = effectiveIsVirtual;
      };

      extraContextModules = funcs.collectContextEnabledModules unifiedArgsWithVmState;

      buildModulesForCollection = lib.recursiveUpdate buildModules extraContextModules;

      processedModulesRaw =
        funcs.collectAllModulesWithSettings unifiedArgsWithVmState mergedModules
          buildModulesForCollection;

      processedModules = lib.mapAttrs (
        _inputName: groups:
        lib.mapAttrs (
          _groupName: modules:
          lib.filterAttrs (_moduleName: settings: (settings.nx_conditionForce or null) != false) modules
        ) groups
      ) processedModulesRaw;

      hostConfig = {
        inherit profileName;
        host = resolvedHost // {
          modules = processedModules;
          configuredModules = mergedModules;
          mainUser = mainUser // {
            modules = processedModules;
          };
        };
        name = resolvedHost.hostname;
        hostname = resolvedHost.hostname;
        users = userAttrSet;
        architecture = arch;
      };

      buildContext = {
        inherit
          system
          pkgs
          lib
          ;
        host = hostConfig.host;
        users = hostConfig.users;
        hostname = hostConfig.hostname;
        configInputs = config.configInputs or { };
        inherit nixOSHosts;
        inherit homeIntegratedUsers;
        inherit homeStandaloneUsers;
        specialArgs = buildSpecialArgs {
          inherit
            pkgs
            ;
          configInputs = config.configInputs or { };
          host = hostConfig.host;
          users = hostConfig.users;
          helpers = localHelpers;
          inherit nixOSHosts;
          inherit homeIntegratedUsers;
          inherit homeStandaloneUsers;
        };
        buildArgs = {
          inherit
            lib
            pkgs
            allOverlays
            unfreePredicate
            inputs
            funcs
            defs
            variables
            ;
          helpers = localHelpers;
          host = hostConfig.host;
          users = hostConfig.users;
          inherit nixOSHosts;
          inherit homeIntegratedUsers;
          inherit homeStandaloneUsers;
          processedModules = processedModules;
          configInputs = config.configInputs or { };
          isVirtual = effectiveIsVirtual;
          isTestingVM = effectiveIsTestingVM;
          isProductionVM = effectiveIsProductionVM;
        };
        diskoModule = getDiskoModule { inherit profileName; };
        hardwareModule = getHardwareModule {
          host = hostConfig.host;
          isPhysical = !effectiveIsVirtual;
        };
      };
    in
    {
      hostConfig = hostConfig;
      buildContext = buildContext;
    };

  processStandaloneUserProfile =
    {
      profileName,
      arch,
      buildArch ? arch,
    }:
    let
      localHelpers = helpers // {
        isHostArchitecture = arch == buildArch;
      };
      funcs = makeFuncs (config + "/profiles/home-standalone/${profileName}");
      userConfigPath = config + "/profiles/home-standalone/${profileName}/${profileName}.nix";

      system = arch;

      preEval = evalConfigModule {
        optionPaths = [
          (build + "/types/shared/all.nix")
          (build + "/types/shared/user.nix")
          (build + "/types/shared/main.nix")
          (build + "/types/home/home-standalone.nix")
        ];
        configPath = userConfigPath;
        specialArgs = {
          inherit
            lib
            variables
            helpers
            defs
            ;
          pkgs = { };
          pkgs-unstable = { };
          self = mkProfileSelf "home-standalone" profileName { };
        };
      };
      profileOverlays = funcs.extractOverlaysFromModule {
        module = preEval.config.user.module or { };
        inherit system variables;
      };

      preBuildModules = funcs.computeStandaloneBuildModules {
        addBaseGroup = preEval.config.user.addBaseGroup or false;
      };

      preEvalUser = enrichUserProfile preEval.config.user profileName true true arch;

      allowedUnfreePackages = lib.unique (
        (variables.allowedUnfreePackages or [ ])
        ++ (preEval.config.user.allowedUnfreePackages or [ ])
        ++ funcs.collectAllModuleUnfreePackages system (preEval.config.user.modules or { }
        ) preBuildModules { } preEvalUser variables inputs
      );

      inherit
        (setupPackages {
          inherit system allowedUnfreePackages;
          extraOverlays = profileOverlays;
        })
        pkgs
        pkgs-unstable
        allOverlays
        unfreePredicate
        ;

      inherit (evalAllProfiles { inherit pkgs pkgs-unstable; })
        nixOSHosts
        homeIntegratedUsers
        homeStandaloneUsers
        ;

      userEval = evalConfigModule {
        optionPaths = [
          (build + "/types/shared/all.nix")
          (build + "/types/shared/user.nix")
          (build + "/types/shared/main.nix")
          (build + "/types/home/home-standalone.nix")
        ];
        configPath = userConfigPath;
        specialArgs = {
          inherit
            lib
            variables
            helpers
            defs
            pkgs
            pkgs-unstable
            ;
          self = mkProfileSelf "home-standalone" profileName {
            inherit nixOSHosts homeIntegratedUsers homeStandaloneUsers;
          };
        };
      };

      resolvedUser = enrichUserProfile userEval.config.user profileName true true arch;

      finalUserConfig = resolvedUser // {
        modules = resolvedUser.modules or { };
      };

      buildContext = {
        inherit
          system
          pkgs
          lib
          ;
        user = finalUserConfig;
        configInputs = config.configInputs or { };
        specialArgs = buildSpecialArgs {
          inherit
            pkgs
            ;
          configInputs = config.configInputs or { };
          user = finalUserConfig;
          helpers = localHelpers;
          inherit nixOSHosts;
          inherit homeIntegratedUsers;
          inherit homeStandaloneUsers;
        };
        buildArgs = {
          inherit
            lib
            pkgs
            allOverlays
            unfreePredicate
            inputs
            funcs
            defs
            variables
            ;
          helpers = localHelpers;
          user = finalUserConfig;
          host = { };
          inherit nixOSHosts;
          inherit homeIntegratedUsers;
          inherit homeStandaloneUsers;
          configInputs = config.configInputs or { };
          isMainUser = true;
          isVirtual = false;
          isTestingVM = false;
          isProductionVM = false;
        };
        extraUserModule = [ ];
      };
    in
    {
      userConfig = finalUserConfig;
      buildContext = buildContext;
    };
}
