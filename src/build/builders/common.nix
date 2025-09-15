{
  lib,
  inputs,
  config,
  build,
  variables,
  helpers,
  defs,
  funcs,
  nixosArchitectures,
  darwinArchitectures,
  allArchitectures,
}:

let
  configInputs = config.configInputs;

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
      nixpkgs ? inputs.nixpkgs,
      nixpkgs-unstable ? inputs.nixpkgs-unstable,
    }:
    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: true;
      };
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfreePredicate = pkg: true;
      };
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

  buildSpecialArgs =
    {
      pkgs,
      pkgs-unstable,
      host ? { },
      users ? { },
      user ? { },
      configInputs ? { },
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
    { profileName, arch }:
    let
      hostConfigPath = config + "/profiles/nixos/${profileName}/${profileName}.nix";

      system = arch;
      inherit (setupPackages { inherit system; }) pkgs pkgs-unstable;

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

      host-data = funcs.applyNixOSHooks {
        inherit
          lib
          helpers
          defs
          funcs
          pkgs
          pkgs-unstable
          inputs
          variables
          ;
        host = hostEval.config.host // {
          architecture = arch;
          isNixOS = true;
          isDarwin = false;
        };
      };

      allUserProfiles = [ host-data.mainUser ] ++ host-data.additionalUsers;

      processIntegratedUser =
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

          user = userEval.config.user // {
            profileName = userProfileName;
            isStandalone = false;
            isIntegrated = true;
            isMainUser = userProfileName == host-data.mainUser;
            architecture = arch;
          };

          userConfig = funcs.applyIntegratedUserHooks {
            inherit
              lib
              helpers
              defs
              funcs
              pkgs
              pkgs-unstable
              inputs
              variables
              ;
            user = user;
            host = host-data;
            configInputs = config.configInputs or { };
            isMainUser = userProfileName == host-data.mainUser;
          };
        in
        {
          name = userConfig.username;
          value = userConfig;
        };

      userAttrSet = builtins.listToAttrs (map processIntegratedUser allUserProfiles);

      mainUser =
        userAttrSet.${
          (builtins.head (builtins.filter (user: user.isMainUser) (builtins.attrValues userAttrSet))).username
        };
      additionalUsers = builtins.filter (user: !user.isMainUser) (builtins.attrValues userAttrSet);

      hostConfig = {
        inherit profileName;
        host = host-data // {
          inherit profileName;
          mainUser = mainUser;
          additionalUsers = additionalUsers;
        };
        name = host-data.hostname;
        hostname = host-data.hostname;
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
            configInputs
            ;
          host = hostConfig.host;
          users = hostConfig.users;
        };
        buildArgs = {
          inherit
            lib
            pkgs
            pkgs-unstable
            inputs
            funcs
            helpers
            defs
            variables
            ;
          host = hostConfig.host;
          users = hostConfig.users;
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
    { profileName, arch }:
    let
      userConfigPath = config + "/profiles/home-standalone/${profileName}/${profileName}.nix";

      system = arch;
      inherit (setupPackages { inherit system; }) pkgs pkgs-unstable;

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

      user = userEval.config.user // {
        architecture = arch;
        isStandalone = true;
        isIntegrated = false;
        isMainUser = true;
      };

      userConfig = funcs.applyStandaloneUserHooks {
        inherit
          lib
          helpers
          defs
          funcs
          pkgs
          pkgs-unstable
          inputs
          variables
          ;
        user = user;
        configInputs = config.configInputs or { };
      };

      finalUserConfig = userConfig // {
        inherit profileName;
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
            configInputs
            ;
          user = finalUserConfig;
        };
        buildArgs = {
          inherit
            lib
            pkgs
            pkgs-unstable
            inputs
            funcs
            helpers
            defs
            variables
            ;
          user = finalUserConfig;
          host = { };
          configInputs = config.configInputs or { };
          isMainUser = true;
        };
        extraUserModule =
          let
            virtualModule =
              if userEval.config.user.configuration != (args: context: { }) then
                let
                  moduleContext = {
                    inputs = inputs;
                    variables = variables;
                    configInputs = config.configInputs or { };
                    moduleBasePath = "profiles/home-standalone/${profileName}";
                    moduleInput = config;
                    moduleInputName = "config";
                    user = finalUserConfig;
                    persist = "${variables.persist.home}/${finalUserConfig.username}";
                  };

                  enhancedContext =
                    moduleContext
                    // (lib.mapAttrs (name: func: func moduleContext) funcs.moduleFuncs.commonFuncs)
                    // {
                      user =
                        moduleContext.user // (lib.mapAttrs (name: func: func moduleContext) funcs.moduleFuncs.userFuncs);
                    };

                  enhancedArgs = buildContext.buildArgs // {
                    self = enhancedContext;
                  };
                in
                [ (userEval.config.user.configuration enhancedArgs) ]
              else
                [ ];
          in
          virtualModule;
      };
    in
    {
      userConfig = finalUserConfig;
      buildContext = buildContext;
    };
}
