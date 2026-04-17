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

  evalConfigModule =
    {
      configPath,
      optionsPath,
      specialArgs ? { },
    }:
    inputs.nixpkgs.lib.evalModules {
      modules = [
        optionsPath
        configPath
      ];
      inherit specialArgs;
    };

  setupPackages =
    {
      system,
      extraOverlays ? [ ],
      nixpkgs ? inputs.nixpkgs,
      nixpkgs-unstable ? inputs.nixpkgs-unstable,
      nixpkgs-darwin ? inputs.nixpkgs-darwin,
      nixpkgs-nix ? inputs.nixpkgs-nix,
    }:
    let
      moduleOverlays = funcs.collectModuleOverlays system;
      overlays = moduleOverlays ++ extraOverlays;

      pkgs-unstable = import nixpkgs-unstable {
        inherit system overlays;
        config.allowUnfreePredicate = pkg: true;
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

      pkgs-nix = import nixpkgs-nix { inherit system; };

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

      buildPkgs =
        nixpkgs:
        import nixpkgs {
          inherit system;
          overlays = overlays ++ [
            (final: prev: unstableOverrides)
            nixImplOverlay
            nixToolsOverlay
          ];
          config.allowUnfreePredicate = pkg: true;
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
      inherit pkgs pkgs-unstable;
    };

  getHardwareModule =
    host:
    if host.nixHardwareModule != null then
      [ (inputs.nixos-hardware + "/${host.nixHardwareModule}") ]
    else
      [ ];

  getDiskoModule =
    { profileName }:
    let
      diskoPath = config + "/profiles/nixos/${profileName}/disk.nix";
    in
    if builtins.pathExists diskoPath then
      [
        inputs.disko.nixosModules.disko
        diskoPath
      ]
    else
      [ ];

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

  buildSpecialArgs =
    {
      pkgs,
      pkgs-unstable,
      host ? { },
      users ? { },
      user ? { },
      configInputs ? { },
      helpers ? helpers,
    }:
    {
      inherit pkgs-unstable;
      inherit inputs;
      inherit variables;
      inherit funcs;
      inherit helpers;
      inherit defs;
      inherit configInputs;
    }
    // lib.optionalAttrs (host != { }) { inherit host; }
    // lib.optionalAttrs (users != { }) { inherit users; }
    // lib.optionalAttrs (user != { }) { inherit user; };
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
    }:
    let
      localHelpers = helpers // {
        isHostArchitecture = arch == buildArch;
      };
      funcs = makeFuncs (config + "/profiles/nixos/${profileName}");
      hostConfigPath = config + "/profiles/nixos/${profileName}/${profileName}.nix";

      system = arch;

      preEval = evalConfigModule {
        optionsPath = build + "/types/system/nixos.nix";
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
        };
      };
      profileOverlays = funcs.extractOverlaysFromModule {
        module = preEval.config.host.module or { };
        inherit system;
      };

      inherit
        (setupPackages {
          inherit system;
          extraOverlays = profileOverlays;
        })
        pkgs
        pkgs-unstable
        ;

      hostEval = evalConfigModule {
        optionsPath = build + "/types/system/nixos.nix";
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
            optionsPath = build + "/types/home/home-integrated.nix";
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
            };
          };
        in
        userEval.config.user
        // {
          profileName = userProfileName;
          isStandalone = false;
          isIntegrated = true;
          isMainUser = userProfileName == rawHost.mainUser;
          architecture = arch;
          home = resolveHomePath {
            user = userEval.config.user;
            inherit arch;
          };
        };

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

      resolvedHost = rawHost // {
        inherit profileName;
        mainUser = mainUser;
        additionalUsers = additionalUsers;
      };

      mergedModules = funcs.mergeModulesWithPrecedence (helpers.ifSet (rawHost.modules or { }) { }) (
        lib.foldl lib.recursiveUpdate { } [
          (mainUser.modules or { })
          (rawHost.userDefaults.modules or { })
        ]
      );

      buildModules =
        lib.recursiveUpdate
          (lib.recursiveUpdate
            {
              groups.build.nixos = true;
              groups.build.home-integrated = true;
            }
            (
              if resolvedHost.addBaseGroup then
                {
                  groups.base.nixos = true;
                }
              else
                { }
            )
          )
          (
            if (mainUser.addBaseGroup && resolvedHost.settings.system.desktop != null) then
              {
                groups.base.home-manager = true;
              }
            else
              { }
          );

      unifiedArgs = {
        inherit
          lib
          pkgs
          pkgs-unstable
          inputs
          variables
          defs
          funcs
          ;
        helpers = localHelpers;
        host = resolvedHost;
        user = mainUser;
        users = userAttrSet;
        configInputs = config.configInputs or { };
      };

      processedModules = funcs.collectAllModulesWithSettings unifiedArgs mergedModules buildModules;

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
          pkgs-unstable
          lib
          ;
        host = hostConfig.host;
        users = hostConfig.users;
        hostname = hostConfig.hostname;
        configInputs = config.configInputs or { };
        specialArgs = buildSpecialArgs {
          inherit
            pkgs
            pkgs-unstable
            ;
          configInputs = config.configInputs or { };
          host = hostConfig.host;
          users = hostConfig.users;
          helpers = localHelpers;
        };
        buildArgs = {
          inherit
            lib
            pkgs
            pkgs-unstable
            inputs
            funcs
            defs
            variables
            ;
          helpers = localHelpers;
          host = hostConfig.host;
          users = hostConfig.users;
          processedModules = processedModules;
          configInputs = config.configInputs or { };
        };
        diskoModule = getDiskoModule { inherit profileName; };
        hardwareModule = getHardwareModule hostConfig.host;
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
        optionsPath = build + "/types/home/home-standalone.nix";
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
        };
      };
      profileOverlays = funcs.extractOverlaysFromModule {
        module = preEval.config.user.module or { };
        inherit system;
      };

      inherit
        (setupPackages {
          inherit system;
          extraOverlays = profileOverlays;
        })
        pkgs
        pkgs-unstable
        ;

      userEval = evalConfigModule {
        optionsPath = build + "/types/home/home-standalone.nix";
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
        };
      };

      resolvedUser = userEval.config.user // {
        inherit profileName;
        architecture = arch;
        isStandalone = true;
        isIntegrated = false;
        isMainUser = true;
        home = resolveHomePath {
          user = userEval.config.user;
          inherit arch;
        };
      };

      buildModules =
        lib.recursiveUpdate
          {
            groups.build.home-standalone = true;
          }
          (
            if resolvedUser.addBaseGroup then
              {
                groups.base.home-manager = true;
              }
            else
              { }
          );

      unifiedArgs = {
        inherit
          lib
          pkgs
          pkgs-unstable
          inputs
          funcs
          defs
          variables
          ;
        helpers = localHelpers;
        user = resolvedUser;
        host = { };
        configInputs = config.configInputs or { };
        isMainUser = true;
      };

      processedModules = funcs.collectAllModulesWithSettings unifiedArgs (resolvedUser.modules or { }
      ) buildModules;

      finalUserConfig = resolvedUser // {
        modules = processedModules;
        configuredModules = resolvedUser.modules or { };
      };

      buildContext = {
        inherit
          system
          pkgs
          pkgs-unstable
          lib
          ;
        user = finalUserConfig;
        configInputs = config.configInputs or { };
        specialArgs = buildSpecialArgs {
          inherit
            pkgs
            pkgs-unstable
            ;
          configInputs = config.configInputs or { };
          user = finalUserConfig;
          helpers = localHelpers;
        };
        buildArgs = {
          inherit
            lib
            pkgs
            pkgs-unstable
            inputs
            funcs
            defs
            variables
            ;
          helpers = localHelpers;
          user = finalUserConfig;
          host = { };
          configInputs = config.configInputs or { };
          isMainUser = true;
        };
        extraUserModule = [ ];
      };
    in
    {
      userConfig = finalUserConfig;
      buildContext = buildContext;
    };
}
