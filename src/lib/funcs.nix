{
  lib,
  defs,
  additionalInputs,
}:
let
  helpers = import ./helpers.nix {
    inherit lib defs additionalInputs;
  };

  moduleFuncs = import (additionalInputs.lib + "/moduleFuncs.nix") {
    inherit lib defs additionalInputs;
  };

  buildModulePath =
    {
      input,
      group,
      name,
    }:
    input + "/modules/${group}/${name}.nix";
in
rec {
  inherit moduleFuncs;

  extractPathComponents =
    filePath: inputName:
    let
      pathStr = toString filePath;
      inputPath = toString (helpers.resolveInputFromInput inputName);

      relativePath = lib.removePrefix inputPath pathStr;
      cleanRelativePath = lib.removePrefix "/" relativePath;
      parts = lib.splitString "/" cleanRelativePath;

      moduleIndex = lib.findFirst (i: builtins.elemAt parts i == "modules") null (
        lib.range 0 (builtins.length parts - 1)
      );
    in
    if moduleIndex == null || moduleIndex + 2 >= builtins.length parts then
      null
    else
      let
        group = builtins.elemAt parts (moduleIndex + 1);
        actualFilename = builtins.baseNameOf pathStr;
        module = lib.removeSuffix ".nix" actualFilename;
      in
      if lib.hasSuffix ".nix" actualFilename then { inherit group module; } else null;

  validateModule =
    moduleResult: filePath: moduleContext:
    let
      correctFormat = builtins.isAttrs moduleResult && !builtins.isFunction moduleResult;

      approvedAttrs = [
        "name"
        "description"
        "group"
        "input"
        "submodules"
        "settings"
        "assertions"
        "custom"
        "on"
        "unfree"
        "warning"
        "error"
        "broken"
        "options"
        "rawOptions"
        "platforms"
        "requiredPlatforms"
        "architectures"
        "requiredArchitectures"
      ];

      actualAttrs = builtins.attrNames moduleResult;

      fileName = builtins.baseNameOf filePath;
      expectedName = lib.removeSuffix ".nix" fileName;
      actualName = moduleResult.name or "";

      invalidAttrs = builtins.filter (attr: !(builtins.elem attr approvedAttrs)) actualAttrs;

      nameValidationError =
        if !(moduleResult ? name) then
          "Module missing required 'name' field. The name field must exactly match the filename (without .nix)."
        else if actualName != expectedName then
          "Module name '${actualName}' does not match filename '${expectedName}'. The name field must exactly match the filename (without .nix extension)."
        else
          null;

      pathComponents = extractPathComponents filePath (moduleContext.inputName or "unknown");
      pathValidationErrors =
        if pathComponents == null then
          [
            "Could not extract path components from module path. Ensure module is in correct location: modules/GROUP/MODULE.nix"
          ]
        else
          let
            inputError =
              if !(moduleResult ? input) then
                "Module missing required 'input' field"
              else if moduleResult.input != moduleContext.inputName then
                "Module input '${moduleResult.input}' does not match expected '${moduleContext.inputName}'"
              else
                null;

            groupError =
              if !(moduleResult ? group) then
                "Module missing required 'group' field"
              else if moduleResult.group != pathComponents.group then
                "Module group '${moduleResult.group}' does not match path '${pathComponents.group}'"
              else
                null;
          in
          builtins.filter (x: x != null) [
            inputError
            groupError
          ];
      topLevelErrorMessage = ''
        File ${filePath} uses invalid top-level attributes: ${builtins.concatStringsSep ", " invalidAttrs}

        Modules can only use these top-level attributes:
          ${builtins.concatStringsSep " " approvedAttrs}

        Please move custom attributes into the 'custom' attribute set:
          custom = {
            ${builtins.concatStringsSep "\n    " (map (attr: "${attr} = ...;") invalidAttrs)}
          };
      '';
      formatErrorMessage = ''
        File ${filePath} uses invalid format!

        Check template file to see valid example file: ${defs.rootPath + "/templates/modules/module.nix"}
      '';

      pathErrorMessage = ''
        File ${filePath} has path validation errors:
        ${builtins.concatStringsSep "\n" pathValidationErrors}
      '';

      attrValueErrors =
        let
          check =
            attr: valid:
            let
              val = moduleResult.${attr} or null;
              invalid = if val == null then [ ] else builtins.filter (x: !(builtins.elem x valid)) val;
            in
            if invalid != [ ] then
              "'${attr}' contains invalid values: ${builtins.concatStringsSep ", " invalid}. Allowed values: ${builtins.concatStringsSep ", " valid}."
            else
              null;
          validPlatforms = [
            "linux"
            "darwin"
          ];
          validArchitectures = [
            "x86_64"
            "aarch64"
          ];
        in
        builtins.filter (x: x != null) [
          (check "platforms" validPlatforms)
          (check "requiredPlatforms" validPlatforms)
          (check "architectures" validArchitectures)
          (check "requiredArchitectures" validArchitectures)
        ];
    in
    if !correctFormat then
      throw formatErrorMessage
    else if nameValidationError != null then
      throw "${filePath}: ${nameValidationError}"
    else if pathValidationErrors != [ ] then
      throw pathErrorMessage
    else if invalidAttrs != [ ] then
      throw topLevelErrorMessage
    else if attrValueErrors != [ ] then
      throw "${filePath}: ${builtins.head attrValueErrors}"
    else if (moduleResult.settings or { }) ? enable then
      throw "${filePath}: 'enable' is a reserved name and cannot be used in settings. It is auto-injected by the build system."
    else if (moduleResult.options or { }) ? enable then
      throw "${filePath}: 'enable' is a reserved name and cannot be used in options. It is auto-injected by the build system."
    else if (moduleResult.settings or { }) ? meta then
      throw "${filePath}: 'meta' is a reserved name and cannot be used in settings. It is auto-injected by the build system."
    else if (moduleResult.options or { }) ? meta then
      throw "${filePath}: 'meta' is a reserved name and cannot be used in options. It is auto-injected by the build system."
    else if (moduleResult.settings or { }) != { } && (moduleResult.options or { }) != { } then
      throw "${filePath}: Modules cannot have both 'settings' and 'options' fields. Use either settings (with auto-generated options) OR options (with merged settings forwarded to them), but not both. This ensures all merged settings are visible at config.nx.*."
    else
      let
        moduleWarning = moduleResult.warning or null;
        moduleError = moduleResult.error or null;
        moduleBroken = moduleResult.broken or false;

        architecture =
          moduleContext.architecture
            or (throw "${toString filePath}: validateModule called without architecture in moduleContext");
        currentPlatform =
          if helpers.isLinuxArch architecture then
            "linux"
          else if helpers.isDarwinArch architecture then
            "darwin"
          else
            throw "${toString filePath}: unrecognized platform in architecture '${architecture}'";
        currentArch =
          if helpers.isX86_64Arch architecture then
            "x86_64"
          else if helpers.isAARCH64Arch architecture then
            "aarch64"
          else
            throw "${toString filePath}: unrecognized architecture in '${architecture}'";

        inputImpliedPlatform =
          if moduleContext.inputName == "linux" then
            "linux"
          else if moduleContext.inputName == "darwin" then
            "darwin"
          else
            null;

        platformAllowed = list: builtins.elem currentPlatform list;
        archAllowed = list: builtins.elem currentArch list;

        platformsValue = moduleResult.platforms or null;
        requiredPlatformsValue = moduleResult.requiredPlatforms or null;
        architecturesValue = moduleResult.architectures or null;
        requiredArchitecturesValue = moduleResult.requiredArchitectures or null;

        getCleanPath =
          _:
          let
            pathStr = toString filePath;
            parts = lib.splitString "/" pathStr;
            moduleIndex = lib.findFirst (i: builtins.elemAt parts i == "modules") null (
              lib.range 0 (builtins.length parts - 1)
            );
          in
          if moduleIndex != null && moduleIndex + 2 < builtins.length parts then
            let
              group = builtins.elemAt parts (moduleIndex + 1);
              module = lib.removeSuffix ".nix" (builtins.elemAt parts (moduleIndex + 2));
            in
            "${group}.${module}"
          else
            lib.removeSuffix ".nix" (builtins.baseNameOf pathStr);
      in
      if moduleError != null then
        throw "${getCleanPath null}: ${moduleError}"
      else if moduleBroken then
        throw "${getCleanPath null}: This module is currently broken!"
      else if inputImpliedPlatform != null && currentPlatform != inputImpliedPlatform then
        throw "${getCleanPath null}: This module is in the '${moduleContext.inputName}' input and only supports [${inputImpliedPlatform}] platforms. Current platform: ${currentPlatform}."
      else if requiredPlatformsValue != null && !(platformAllowed requiredPlatformsValue) then
        throw "${getCleanPath null}: This module only supports [${builtins.concatStringsSep ", " requiredPlatformsValue}] platforms. Current platform: ${currentPlatform}."
      else if requiredArchitecturesValue != null && !(archAllowed requiredArchitecturesValue) then
        throw "${getCleanPath null}: This module only supports [${builtins.concatStringsSep ", " requiredArchitecturesValue}] architectures. Current architecture: ${currentArch}."
      else if moduleWarning != null then
        builtins.trace "${getCleanPath null}: ${moduleWarning}" moduleResult
      else if platformsValue != null && !(platformAllowed platformsValue) then
        builtins.trace "${getCleanPath null}: This module is intended for [${builtins.concatStringsSep ", " platformsValue}] platforms. Current platform: ${currentPlatform}." moduleResult
      else if architecturesValue != null && !(archAllowed architecturesValue) then
        builtins.trace "${getCleanPath null}: This module is intended for [${builtins.concatStringsSep ", " architecturesValue}] architectures. Current architecture: ${currentArch}." moduleResult
      else
        moduleResult;

  validateSettingsOverride =
    moduleDefaults: userSettings: inputName: groupName: moduleName:
    let
      defaultAttrs = builtins.attrNames moduleDefaults;
      userAttrs = builtins.attrNames userSettings;
      systemManagedAttrs = [ "nx_unfree" ];
      allowedAttrs = defaultAttrs ++ systemManagedAttrs;
      invalidAttrs = builtins.filter (attr: !(builtins.elem attr allowedAttrs)) userAttrs;
      modulePath = "${inputName}.${groupName}.${moduleName}";
    in
    if invalidAttrs != [ ] then
      throw "Module ${modulePath} settings validation failed: Unknown settings attributes [${builtins.concatStringsSep ", " invalidAttrs}]. Available attributes: [${builtins.concatStringsSep ", " defaultAttrs}]"
    else
      userSettings;

  mergeModuleDefaults =
    lib: helpers: args: inputName: groupName: moduleName: moduleSettings:
    let
      modulePath = helpers.resolveInputFromInput inputName + "/modules/${groupName}/${moduleName}.nix";
    in
    if !builtins.pathExists modulePath then
      if moduleSettings == true then { } else moduleSettings
    else
      let
        moduleDir = "modules/${groupName}/${moduleName}";

        moduleContext = {
          inputs = args.inputs;
          variables = args.variables;
          configInputs = args.configInputs or { };
          moduleBasePath = moduleDir;
          moduleInput = helpers.resolveInputFromInput inputName;
          moduleInputName = inputName;
          settings = { };
          host = args.host;
          user = args.user or (if args ? host && args.host ? mainUser then args.host.mainUser else null);
          users = args.users or { };
          processedModules = args.processedModules or { };
        };

        enhancedModuleContext = injectModuleFuncs moduleContext;

        moduleResult = import modulePath {
          lib = args.lib;
          pkgs = args.pkgs;
          pkgs-unstable = args.pkgs-unstable;
          funcs = args.funcs;
          helpers = args.helpers;
          defs = args.defs;
          self = enhancedModuleContext;
        };

        moduleDefaults = moduleResult.settings or { };
        moduleOptions = moduleResult.options or { };
        moduleRawOptions = moduleResult.rawOptions or { };
        moduleUnfree = moduleResult.unfree or [ ];

        hasSettings = moduleDefaults != { };
        hasStandardOptions = moduleOptions != { };

        userSettings = if moduleSettings == true then { } else moduleSettings;

        validatedUserSettings =
          if userSettings == { } then
            userSettings
          else if !hasSettings && hasStandardOptions then
            userSettings
          else
            validateSettingsOverride moduleDefaults userSettings inputName groupName moduleName;

        settingsWithUnfree =
          if moduleUnfree != [ ] then
            validatedUserSettings // { nx_unfree = moduleUnfree; }
          else
            validatedUserSettings;
      in
      lib.recursiveUpdate moduleDefaults settingsWithUnfree;

  processModules =
    modules:
    builtins.filter (x: x != null) (
      lib.flatten (
        lib.mapAttrsToList (
          inputName: groups:
          lib.flatten (
            lib.mapAttrsToList (
              group: moduleSpecs:
              lib.mapAttrsToList (
                name: value:
                if builtins.isBool value then
                  if value then
                    {
                      inherit inputName group name;
                      input = helpers.resolveInputFromInput inputName;
                      settings = { };
                    }
                  else
                    null
                else if builtins.isAttrs value then
                  {
                    inherit inputName group name;
                    input = helpers.resolveInputFromInput inputName;
                    settings = value;
                  }
                else
                  throw "Module '${inputName}.${group}.${name}' must be true, false, or an attribute set"
              ) moduleSpecs
            ) groups
          )
        ) modules
      )
    );

  injectModuleFuncs =
    moduleContext:
    let
      appliedCommonFuncs = lib.mapAttrs (name: func: func moduleContext) moduleFuncs.commonFuncs;

      contextFuncs = {
        host = moduleContext.host or { };
        user = moduleContext.user or null;
      };

      hierarchicalFuncs = moduleFuncs.hierarchicalInputFuncs moduleContext moduleContext.moduleBasePath;

      persistShortcut = {
        persist = moduleContext.variables.persist;
      };
    in
    moduleContext // appliedCommonFuncs // contextFuncs // hierarchicalFuncs // persistShortcut;

  resolveArchitecture =
    args:
    if args ? host && args.host ? architecture then
      args.host.architecture
    else if args ? user && args.user != null && args.user ? architecture then
      args.user.architecture
    else
      throw "No architecture found in args - cannot determine platform";

  validateOn =
    modulePath: on:
    let
      allowedTopLevel = [
        "init"
        "enabled"
        "home"
        "system"
        "standalone"
        "integrated"
        "linux"
        "darwin"
        "overlays"
      ];

      allowedNested = [
        "init"
        "enabled"
        "home"
        "system"
        "standalone"
        "integrated"
        "overlays"
      ];

      topLevelAttrs = builtins.attrNames on;
      invalidTopLevel = builtins.filter (attr: !(builtins.elem attr allowedTopLevel)) topLevelAttrs;

      validateFn =
        path: name: value:
        if !(builtins.isFunction value) then
          [ "on.${path}${name} must be a function (config: { ... }), got ${builtins.typeOf value}" ]
        else
          [ ];

      validatePlatform =
        platformName: platformOn:
        let
          attrs = builtins.attrNames platformOn;
          invalidAttrs = builtins.filter (attr: !(builtins.elem attr allowedNested)) attrs;
          invalidAttrErrors =
            if invalidAttrs != [ ] then
              [
                "on.${platformName} contains invalid attributes: ${builtins.concatStringsSep ", " invalidAttrs}. Allowed: ${builtins.concatStringsSep ", " allowedNested}"
              ]
            else
              [ ];
          fnAttrsNested = builtins.filter (attr: attr != "overlays") attrs;
          fnErrors = lib.concatMap (
            name: validateFn "${platformName}." name platformOn.${name}
          ) fnAttrsNested;
        in
        invalidAttrErrors ++ fnErrors;

      topLevelErrors =
        if invalidTopLevel != [ ] then
          [
            "on contains invalid attributes: ${builtins.concatStringsSep ", " invalidTopLevel}. Allowed: ${builtins.concatStringsSep ", " allowedTopLevel}"
          ]
        else
          [ ];

      fnAttrs = builtins.filter (
        attr: attr != "linux" && attr != "darwin" && attr != "overlays"
      ) topLevelAttrs;

      fnErrors = lib.concatMap (name: validateFn "" name on.${name}) fnAttrs;

      platformErrors =
        (
          if on ? linux && builtins.isAttrs on.linux then
            validatePlatform "linux" on.linux
          else if on ? linux then
            [ "on.linux must be an attribute set, got ${builtins.typeOf on.linux}" ]
          else
            [ ]
        )
        ++ (
          if on ? darwin && builtins.isAttrs on.darwin then
            validatePlatform "darwin" on.darwin
          else if on ? darwin then
            [ "on.darwin must be an attribute set, got ${builtins.typeOf on.darwin}" ]
          else
            [ ]
        );

      allErrors = topLevelErrors ++ fnErrors ++ platformErrors;
    in
    if allErrors != [ ] then
      throw "Module ${modulePath} has invalid 'on' configuration:\n  ${builtins.concatStringsSep "\n  " allErrors}"
    else
      on;

  selectApplicableOnFns =
    {
      on,
      buildContext,
      architecture,
      includeInit ? false,
    }:
    let
      isLinux = helpers.isLinuxArch architecture;
      isDarwin = helpers.isDarwinArch architecture;
      platformOn =
        if isLinux then
          on.linux or { }
        else if isDarwin then
          on.darwin or { }
        else
          { };

      isHome = buildContext == "home-standalone" || buildContext == "home-integrated";
      isStandalone = buildContext == "home-standalone";
      isIntegrated = buildContext == "home-integrated";

      tag = fn: type: { inherit fn type; };
    in
    lib.optional (includeInit && on ? init) (tag on.init "init")
    ++ lib.optional (includeInit && platformOn ? init) (tag platformOn.init "init")
    ++ lib.optional (on ? enabled) (tag on.enabled "enabled")
    ++ lib.optional (platformOn ? enabled) (tag platformOn.enabled "enabled")
    ++ lib.optional (isHome && on ? home) (tag on.home "home")
    ++ lib.optional (isHome && platformOn ? home) (tag platformOn.home "home")
    ++ lib.optional (isHome && isStandalone && on ? standalone) (tag on.standalone "standalone")
    ++ lib.optional (isHome && isStandalone && platformOn ? standalone) (
      tag platformOn.standalone "standalone"
    )
    ++ lib.optional (isHome && isIntegrated && on ? integrated) (tag on.integrated "integrated")
    ++ lib.optional (isHome && isIntegrated && platformOn ? integrated) (
      tag platformOn.integrated "integrated"
    )
    ++ lib.optional (!isHome && on ? system) (tag on.system "system")
    ++ lib.optional (!isHome && platformOn ? system) (tag platformOn.system "system");

  mergeOnFunctions =
    moduleIdentifier: fns:
    if fns == [ ] then
      { }
    else
      { config, ... }:
      let
        contextSpecific = [
          "home"
          "system"
          "integrated"
        ];
        callAndValidate =
          { fn, type }:
          let
            result = fn config;
          in
          if (result ? nx) && (builtins.elem type contextSpecific) then
            throw "Module ${moduleIdentifier}: nx.* options cannot be set in on.${type}.\n\nUse on.init or on.enabled for shared options or on.standalone for home-manager only options (only works in home-manager only profiles)!"
          else
            result;
      in
      lib.mkMerge (map callAndValidate fns);

  importModule =
    args: moduleSpec: allProcessedModules: buildContext:
    let
      modulePath = buildModulePath {
        input = moduleSpec.input;
        group = moduleSpec.group;
        name = moduleSpec.name;
      };
      moduleDir = "modules/${moduleSpec.group}/${moduleSpec.name}";

      basicModuleResult = import modulePath {
        lib = args.lib;
        pkgs = args.pkgs;
        pkgs-unstable = args.pkgs-unstable;
        funcs = args.funcs;
        helpers = args.helpers;
        defs = args.defs;
        self = { };
      };

      moduleContext = {
        inputs = args.inputs;
        host = args.host or { };
        user = args.user or null;
        users = args.users or { };
        variables = args.variables;
        configInputs = args.configInputs or { };
        moduleBasePath = moduleDir;
        moduleInput = moduleSpec.input;
        moduleInputName = moduleSpec.inputName;
        settings = moduleSpec.settings or { };
        unfree = basicModuleResult.unfree or [ ];
        processedModules = allProcessedModules;
      };

      enhancedModuleContext = injectModuleFuncs moduleContext;

      consolidatedArgs = {
        lib = args.lib;
        pkgs = args.pkgs;
        pkgs-unstable = args.pkgs-unstable;
        funcs = args.funcs;
        helpers = args.helpers;
        defs = args.defs;
        self = enhancedModuleContext;
      };

      moduleResult = validateModule (import modulePath consolidatedArgs) modulePath {
        inputName = moduleSpec.inputName;
        architecture = resolveArchitecture args;
      };

      on = validateOn modulePath (moduleResult.on or { });
      architecture = resolveArchitecture args;

      applicableFns = selectApplicableOnFns {
        inherit on buildContext architecture;
      };

      configFn = mergeOnFunctions (toString modulePath) applicableFns;
    in
    {
      configuration = configFn;
      submodules = moduleResult.submodules or { };
    };

  importModules =
    args: moduleSpecs: allProcessedModules: buildContext:
    let
      moduleResults = map (spec: importModule args spec allProcessedModules buildContext) moduleSpecs;
    in
    {
      modules = map (result: result.configuration) moduleResults;
      submodules = lib.foldl lib.recursiveUpdate { } (map (result: result.submodules) moduleResults);
    };

  processProfileOn =
    {
      profile,
      profileType,
      profileName,
      args,
      processedModules,
      buildContext,
    }:
    let
      on = validateOn "profile:${profileType}/${profileName}" (profile.on or { });
      architecture = resolveArchitecture args;

      moduleContext = {
        inputs = args.inputs;
        variables = args.variables;
        configInputs = args.configInputs or { };
        moduleBasePath = "profiles/${profileType}/${profileName}";
        moduleInput = args.configInputs.config or args.inputs.config;
        moduleInputName = "config";
        host = args.host or { };
        user = args.user or null;
        users = args.users or { };
        processedModules = processedModules;
      };

      enhancedContext = injectModuleFuncs moduleContext;

      enhancedArgs = args // {
        self = enhancedContext;
      };

      isLinux = helpers.isLinuxArch architecture;
      isDarwin = helpers.isDarwinArch architecture;
      platformOn =
        if isLinux then
          on.linux or { }
        else if isDarwin then
          on.darwin or { }
        else
          { };

      tag = fn: type: { inherit fn type; };
      initFns =
        lib.optional (on ? init) (tag on.init "init")
        ++ lib.optional (platformOn ? init) (tag platformOn.init "init");

      contextFns = selectApplicableOnFns {
        inherit on buildContext architecture;
      };

      applyArgs =
        { fn, type }:
        {
          fn = (config: fn enhancedArgs config);
          inherit type;
        };
    in
    {
      initModules =
        let
          applied = map applyArgs initFns;
        in
        if applied == [ ] then
          [ ]
        else
          [ (mergeOnFunctions "profile:${profileType}/${profileName}" applied) ];

      contextModules =
        let
          applied = map applyArgs contextFns;
        in
        if applied == [ ] then
          [ ]
        else
          [ (mergeOnFunctions "profile:${profileType}/${profileName}" applied) ];
    };

  collectModuleAssertions =
    args: processedModules:
    let
      collectFromModules =
        modules:
        lib.flatten (
          lib.mapAttrsToList (
            inputName: inputGroups:
            lib.mapAttrsToList (
              groupName: groupModules:
              lib.mapAttrsToList (
                moduleName: moduleSettings:
                let
                  moduleSpec = {
                    input = args.inputs.${inputName};
                    inputName = inputName;
                    group = groupName;
                    name = moduleName;
                    settings = moduleSettings;
                  };
                  modulePath = buildModulePath {
                    input = moduleSpec.input;
                    group = moduleSpec.group;
                    name = moduleSpec.name;
                  };
                  moduleResult = import modulePath {
                    lib = args.lib;
                    pkgs = args.pkgs;
                    pkgs-unstable = args.pkgs-unstable;
                    funcs = args.funcs;
                    helpers = args.helpers;
                    defs = args.defs;
                    self = { };
                  };
                in
                map (
                  assertion:
                  assertion
                  // {
                    moduleSpec = moduleSpec;
                    modulePath = modulePath;
                  }
                ) (moduleResult.assertions or [ ])
              ) groupModules
            ) inputGroups
          ) modules
        );
    in
    collectFromModules processedModules;

  evaluateModuleAssertions =
    args: moduleContext: assertion:
    let
      fullModuleContext = {
        inputs = args.inputs;
        host = args.host or { };
        user =
          if args ? user then
            args.user
          else if args ? host && args.host ? mainUser then
            args.host.mainUser
          else
            null;
        users = args.users or { };
        variables = args.variables;
        configInputs = args.configInputs or { };
        moduleBasePath = "modules/${assertion.moduleSpec.group}/${assertion.moduleSpec.name}";
        moduleInput = assertion.moduleSpec.input;
        moduleInputName = assertion.moduleSpec.inputName;
        settings = assertion.moduleSpec.settings;
        processedModules = moduleContext.processedModules or { };
      };

      enhancedContext = injectModuleFuncs fullModuleContext;

      consolidatedArgs = {
        lib = args.lib;
        pkgs = args.pkgs;
        pkgs-unstable = args.pkgs-unstable;
        funcs = args.funcs;
        helpers = args.helpers;
        defs = args.defs;
        self = enhancedContext;
      };

      moduleResult = import assertion.modulePath consolidatedArgs;
      moduleAssertions = moduleResult.assertions or [ ];
      targetAssertion = builtins.head (
        builtins.filter (a: a.message == assertion.message) moduleAssertions
      );
    in
    {
      assertion = targetAssertion.assertion;
      message = "Module ${assertion.moduleSpec.inputName}.${assertion.moduleSpec.group}.${assertion.moduleSpec.name} assertion failed: ${targetAssertion.message}";
    };

  normalizeListsToAttrsets =
    modules:
    lib.mapAttrs (
      inputName: inputGroups:
      lib.mapAttrs (
        groupName: groupModules:
        if builtins.isList groupModules then
          lib.listToAttrs (
            map (name: {
              name = name;
              value = true;
            }) groupModules
          )
        else
          groupModules
      ) inputGroups
    ) modules;

  collectSubModules =
    args: moduleSpecs:
    let
      moduleResults = map (
        moduleSpec:
        let
          modulePath = buildModulePath {
            input = moduleSpec.input;
            group = moduleSpec.group;
            name = moduleSpec.name;
          };
          moduleDir = "modules/${moduleSpec.group}/${moduleSpec.name}";

          moduleContext = {
            inputs = args.inputs or args.self.inputs;
            variables = args.variables or args.self.variables;
            configInputs = args.configInputs or args.self.configInputs or { };
            moduleBasePath = moduleDir;
            moduleInput = moduleSpec.input;
            moduleInputName = moduleSpec.inputName;
            settings = moduleSpec.settings or { };
            host = args.host or args.self.host or { };
            user = args.user or args.self.user or null;
            users = args.users or args.self.users or { };
            processedModules = args.processedModules or { };
          };

          enhancedModuleContext = injectModuleFuncs moduleContext;

          consolidatedArgs = {
            lib = args.lib;
            pkgs = args.pkgs;
            pkgs-unstable = args.pkgs-unstable;
            funcs = args.funcs;
            helpers = args.helpers;
            defs = args.defs;
            self = enhancedModuleContext;
          };

          moduleResult = import modulePath consolidatedArgs;
        in
        let
          rawSubmodules = normalizeListsToAttrsets (moduleResult.submodules or { });
          filterAndNormalizeSubmodules =
            submodules:
            lib.mapAttrs (
              inputName: inputGroups:
              lib.mapAttrs (
                groupName: groupModules:
                lib.mapAttrs (moduleName: moduleValue: if moduleValue == true then { } else moduleValue) (
                  lib.filterAttrs (moduleName: moduleValue: moduleValue != false) groupModules
                )
              ) inputGroups
            ) submodules;
        in
        filterAndNormalizeSubmodules rawSubmodules
      ) moduleSpecs;
    in
    lib.foldl lib.recursiveUpdate { } moduleResults;

  mergeSubModules = submodulesList: lib.foldl lib.recursiveUpdate { } submodulesList;

  mergeModuleValue =
    a: b:
    let
      normalizeValue = v: if v == true then { } else v;

      normalA = normalizeValue a;
      normalB = normalizeValue b;

      getPrecedence =
        v:
        if builtins.isAttrs v then
          2
        else if v == true then
          1
        else
          0;

      precedenceA = getPrecedence a;
      precedenceB = getPrecedence b;
    in
    if precedenceA > precedenceB then
      normalA
    else if precedenceB > precedenceA then
      normalB
    else if builtins.isAttrs normalA && builtins.isAttrs normalB then
      lib.recursiveUpdate normalA normalB
    else
      normalB;

  zipWithMerge =
    mergeFn: a: b:
    lib.zipAttrsWith
      (
        _: values:
        if builtins.length values == 1 then
          builtins.head values
        else
          mergeFn (builtins.elemAt values 0) (builtins.elemAt values 1)
      )
      [
        a
        b
      ];

  mergeModulesWithPrecedence =
    modules1: modules2:
    let
      normalizeInput = v: if v == true then { } else v;
    in
    zipWithMerge (
      inputA: inputB:
      zipWithMerge (
        groupA: groupB: zipWithMerge mergeModuleValue (normalizeInput groupA) (normalizeInput groupB)
      ) (normalizeInput inputA) (normalizeInput inputB)
    ) modules1 modules2;

  collectAllModulesWithSettings =
    args: initialModules: buildModules:
    let
      filterFalseValues =
        modules:
        lib.mapAttrs (
          inputName: inputGroups:
          lib.mapAttrs (
            groupName: groupModules:
            lib.filterAttrs (moduleName: moduleSettings: moduleSettings != false) groupModules
          ) inputGroups
        ) modules;

      normalizeModules =
        modules:
        lib.mapAttrs (
          inputName: inputGroups:
          lib.mapAttrs (
            groupName: groupModules:
            lib.mapAttrs (
              moduleName: moduleSettings: if moduleSettings == true then { } else moduleSettings
            ) groupModules
          ) inputGroups
        ) modules;

      applyDefaultsToModules =
        modules:
        lib.mapAttrs (
          inputName: inputGroups:
          lib.mapAttrs (
            groupName: groupModules:
            lib.mapAttrs (
              moduleName: moduleSettings:
              mergeModuleDefaults lib helpers args inputName groupName moduleName moduleSettings
            ) groupModules
          ) inputGroups
        ) modules;

      normalizedListSyntax = normalizeListsToAttrsets (lib.recursiveUpdate initialModules buildModules);
      filteredInitialModules = filterFalseValues normalizedListSyntax;
      normalizedInitialModules = normalizeModules filteredInitialModules;

      collectRound =
        processedModules: currentModules: iteration:
        let
          moduleSpecs = processModules currentModules;
          collectedSubmodules = collectSubModules args moduleSpecs;
          filteredSubmodules = filterFalseValues collectedSubmodules;
          normalizedSubmodules = normalizeModules filteredSubmodules;
          collectedSubmodulesWithDefaults = applyDefaultsToModules normalizedSubmodules;

          nextModules = mergeModulesWithPrecedence collectedSubmodulesWithDefaults currentModules;

          hasNewModules =
            let
              flattenModules =
                modules:
                lib.concatMapAttrs (
                  inputName: inputGroups:
                  lib.concatMapAttrs (
                    groupName: groupModules:
                    lib.mapAttrs' (moduleName: _: {
                      name = "${inputName}.${groupName}.${moduleName}";
                      value = true;
                    }) groupModules
                  ) inputGroups
                ) modules;

              currentFlat = flattenModules currentModules;
              processedFlat = flattenModules processedModules;
              newModulesFlat = removeAttrs currentFlat (builtins.attrNames processedFlat);
            in
            newModulesFlat != { };
        in
        if hasNewModules then
          if iteration < 15 then
            collectRound currentModules nextModules (iteration + 1)
          else
            throw "Recursion depth exceeded for collecting modules! Reached ${toString iteration} iterations."
        else
          nextModules;
    in
    let
      finalModules = collectRound { } normalizedInitialModules 0;
      finalModulesWithDefaults = applyDefaultsToModules finalModules;
    in
    finalModulesWithDefaults;

  extractModuleUnfreePackages =
    processedModules:
    let
      collectUnfreeFromModules =
        modules:
        lib.flatten (
          lib.mapAttrsToList (
            inputName: inputGroups:
            lib.mapAttrsToList (
              groupName: groupModules:
              lib.mapAttrsToList (moduleName: moduleSettings: moduleSettings.nx_unfree or [ ]) groupModules
            ) inputGroups
          ) modules
        );
    in
    lib.unique (collectUnfreeFromModules processedModules);

  validateUnfreePackages =
    {
      packages,
      declaredUnfree ? [ ],
      context,
      profileName ? "unknown",
      processedModules ? { },
    }:
    let
      moduleUnfreePackages = extractModuleUnfreePackages processedModules;
      allDeclaredUnfreePackages = declaredUnfree ++ moduleUnfreePackages;

      unfreePackages = builtins.filter (
        pkg:
        let
          isUnfree = pkg.meta.unfree or false;

          hasUnfreeLicense = builtins.any (
            license:
            let
              licenseName = lib.toLower (license.shortName or license.spdxId or "");
            in
            lib.hasInfix "unfree" licenseName
            || lib.hasInfix "proprietary" licenseName
            || licenseName == "unknown"
          ) (lib.toList (pkg.meta.license or [ ]));

        in
        isUnfree || hasUnfreeLicense
      ) packages;

      unfreePackageNames = map (pkg: pkg.pname or pkg.name or "unknown") unfreePackages;

      undeclaredUnfreePackages = builtins.filter (
        packageName:
        !(builtins.any (
          declaredName: packageName == declaredName || lib.hasPrefix declaredName packageName
        ) allDeclaredUnfreePackages)
      ) unfreePackageNames;

      hasUndeclaredUnfreePackages = undeclaredUnfreePackages != [ ];

      configInstructions =
        if context == "system" then
          "host.allowedUnfreePackages = [ ${
            lib.concatMapStringsSep " " (name: "\"${name}\"") undeclaredUnfreePackages
          } ];"
        else
          "user.allowedUnfreePackages = [ ${
            lib.concatMapStringsSep " " (name: "\"${name}\"") undeclaredUnfreePackages
          } ];";

    in
    {
      assertion = !hasUndeclaredUnfreePackages;
      message = ''
        Unfree packages found in ${context} packages but not declared in ${profileName} profile:
        ${lib.concatStringsSep ", " undeclaredUnfreePackages}

        Please add them to your profile:
        ${configInstructions}

        Or declare them in modules that use them:
        unfree = [ ${lib.concatMapStringsSep " " (name: "\"${name}\"") undeclaredUnfreePackages} ];
      '';
    };

  scanAllModulesForInput =
    inputName: input:
    let
      modulesPath = input + "/modules";
    in
    if builtins.pathExists modulesPath then
      let
        groups = builtins.readDir modulesPath;
        scanGroup =
          groupName: groupType:
          if groupType == "directory" then
            let
              groupPath = modulesPath + "/${groupName}";
              entries = builtins.readDir groupPath;
            in
            lib.mapAttrsToList (
              fileName: entryType:
              if entryType == "regular" && lib.hasSuffix ".nix" fileName then
                let
                  moduleName = lib.removeSuffix ".nix" fileName;
                  modulePath = groupPath + "/${fileName}";
                in
                {
                  inherit
                    inputName
                    groupName
                    moduleName
                    modulePath
                    ;
                  input = input;
                }
              else
                null
            ) entries
          else
            [ ];
      in
      lib.flatten (lib.mapAttrsToList scanGroup groups)
    else
      [ ];

  extractOverlaysFromOn =
    { on, system }:
    let
      isLinux = helpers.isLinuxArch system;
      isDarwin = helpers.isDarwinArch system;
      platformOn =
        if isLinux then
          on.linux or { }
        else if isDarwin then
          on.darwin or { }
        else
          { };
    in
    (on.overlays or [ ]) ++ (platformOn.overlays or [ ]);

  collectModuleOverlays =
    system:
    let
      minimalArgs = {
        inherit lib;
        pkgs = { };
        pkgs-unstable = { };
        funcs = { };
        helpers = helpers;
        defs = defs;
        self = { };
      };

      scanInput =
        inputName:
        if additionalInputs ? ${inputName} then
          let
            input = additionalInputs.${inputName};
            moduleSpecs = builtins.filter (x: x != null) (scanAllModulesForInput inputName input);
          in
          lib.concatMap (
            spec:
            let
              moduleResult = builtins.tryEval (import spec.modulePath minimalArgs);
            in
            if moduleResult.success then
              extractOverlaysFromOn {
                on = moduleResult.value.on or { };
                inherit system;
              }
            else
              [ ]
          ) moduleSpecs
        else
          [ ];
    in
    lib.concatMap scanInput defs.moduleInputsToScan;

  collectAllModuleData =
    args:
    let

      minimalArgs = {
        inherit lib;
        pkgs = args.pkgs;
        pkgs-unstable = args.pkgs-unstable;
        funcs = { };
        helpers = args.helpers;
        defs = args.defs;
        self = {
          isDarwin = args.pkgs.stdenv.isDarwin;
          isLinux = args.pkgs.stdenv.isLinux;
          isX86_64 = args.pkgs.stdenv.hostPlatform.isx86_64;
          isAARCH64 = args.pkgs.stdenv.hostPlatform.isAarch64;
        };
      };

      scanInput =
        inputName:
        if additionalInputs ? ${inputName} then
          let
            input = additionalInputs.${inputName};
            moduleSpecs = builtins.filter (x: x != null) (scanAllModulesForInput inputName input);
          in
          map (
            spec:
            let
              moduleResult = builtins.tryEval (import spec.modulePath minimalArgs);
            in
            if moduleResult.success then
              {
                inherit (spec)
                  inputName
                  groupName
                  moduleName
                  modulePath
                  ;
                options = moduleResult.value.options or { };
                rawOptions = moduleResult.value.rawOptions or { };
                settings = moduleResult.value.settings or { };
                description = moduleResult.value.description or "";
              }
            else
              {
                inherit (spec)
                  inputName
                  groupName
                  moduleName
                  modulePath
                  ;
                options = { };
                rawOptions = { };
                settings = { };
                description = "";
              }
          ) moduleSpecs
        else
          [ ];

      allModuleData = lib.flatten (map scanInput defs.moduleInputsToScan);
    in
    allModuleData;

  collectAllModuleOptions =
    args: builtins.filter (m: m.options != { } || m.rawOptions != { }) (collectAllModuleData args);

  generateOptionsModules =
    allModuleData:
    let
      moduleOptionsModules = map (
        m:
        if m.options != { } then
          {
            options.nx.${m.inputName}.${m.groupName}.${m.moduleName} = lib.mapAttrs (
              name: spec: if spec._type or null == "option" then spec else lib.mkOption spec
            ) m.options;
          }
        else
          { }
      ) allModuleData;

      rawOptionsModules = map (m: if m.rawOptions != { } then { options = m.rawOptions; } else { }) (
        builtins.filter (m: m.rawOptions != { }) allModuleData
      );

      settingsOptionsModules = map (
        m:
        if m.settings != { } && m.options == { } && m.rawOptions == { } then
          {
            options.nx.${m.inputName}.${m.groupName}.${m.moduleName} = lib.mapAttrs (
              name: defaultValue:
              lib.mkOption {
                type = lib.types.anything;
                default = defaultValue;
              }
            ) m.settings;
          }
        else
          { }
      ) allModuleData;

      enableOptionsModules = map (m: {
        options.nx.${m.inputName}.${m.groupName}.${m.moduleName}.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      }) allModuleData;

      metaOptionsModules = map (m: {
        options.nx.${m.inputName}.${m.groupName}.${m.moduleName}.meta = lib.mkOption {
          type = lib.types.submodule {
            options = {
              description = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              input = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              group = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
              name = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
            };
          };
          default = { };
        };
      }) allModuleData;
    in
    (builtins.filter (m: m != { }) moduleOptionsModules)
    ++ rawOptionsModules
    ++ (builtins.filter (m: m != { }) settingsOptionsModules)
    ++ enableOptionsModules
    ++ metaOptionsModules;

  generateSettingsValueModules =
    allModuleData: processedModules:
    let
      settingsOnlyModules = builtins.filter (
        m: m.settings != { } && m.options == { } && m.rawOptions == { }
      ) allModuleData;
      systemManagedAttrs = [ "nx_unfree" ];
    in
    map (
      m:
      let
        mergedSettings = processedModules.${m.inputName}.${m.groupName}.${m.moduleName} or { };
        filteredSettings = removeAttrs mergedSettings systemManagedAttrs;
      in
      { config, ... }:
      {
        config.nx.${m.inputName}.${m.groupName}.${m.moduleName} = filteredSettings;
      }
    ) settingsOnlyModules;

  generateOptionsValueModules =
    allModuleData: processedModules:
    let
      optionsOnlyModules = builtins.filter (m: m.options != { } && m.settings == { }) allModuleData;
      systemManagedAttrs = [ "nx_unfree" ];
    in
    map (
      m:
      let
        mergedSettings = processedModules.${m.inputName}.${m.groupName}.${m.moduleName} or { };
        filteredSettings = removeAttrs mergedSettings systemManagedAttrs;
      in
      { config, ... }:
      {
        config.nx.${m.inputName}.${m.groupName}.${m.moduleName} = lib.mapAttrs (
          name: value: value
        ) filteredSettings;
      }
    ) optionsOnlyModules;

  generateEnableValueModules =
    allModuleData: processedModules:
    map (
      m:
      let
        isEnabled =
          processedModules ? ${m.inputName}
          && processedModules.${m.inputName} ? ${m.groupName}
          && processedModules.${m.inputName}.${m.groupName} ? ${m.moduleName};
      in
      { config, ... }:
      {
        config.nx.${m.inputName}.${m.groupName}.${m.moduleName}.enable = isEnabled;
      }
    ) allModuleData;

  generateMetaValueModules =
    allModuleData:
    map (
      m:
      let
        autoDescription = lib.strings.concatStrings [
          (lib.strings.toUpper (lib.strings.substring 0 1 m.moduleName))
          (lib.strings.substring 1 (-1) m.moduleName)
          " Configuration"
        ];
        finalDescription = if m.description != "" then m.description else autoDescription;
      in
      { config, ... }:
      {
        config.nx.${m.inputName}.${m.groupName}.${m.moduleName}.meta = {
          description = finalDescription;
          input = m.inputName;
          group = m.groupName;
          name = m.moduleName;
        };
      }
    ) allModuleData;

  importAllModuleInits =
    args:
    let
      architecture = resolveArchitecture args;
      isLinux = helpers.isLinuxArch architecture;
      isDarwin = helpers.isDarwinArch architecture;

      scanInput =
        inputName:
        if additionalInputs ? ${inputName} then
          let
            input = additionalInputs.${inputName};
            moduleSpecs = builtins.filter (x: x != null) (scanAllModulesForInput inputName input);
          in
          lib.flatten (
            map (
              spec:
              let
                moduleDir = "modules/${spec.groupName}/${spec.moduleName}";

                moduleContext = {
                  inputs = args.inputs;
                  variables = args.variables;
                  configInputs = args.configInputs or { };
                  moduleBasePath = moduleDir;
                  moduleInput = spec.input;
                  moduleInputName = spec.inputName;
                  settings = { };
                  host = args.host or { };
                  users = args.users or { };
                  user = args.user or null;
                  processedModules = args.processedModules or { };
                };

                enhancedModuleContext = injectModuleFuncs moduleContext;

                contextWithOptions = enhancedModuleContext // {
                  options = config: config.nx.${spec.inputName}.${spec.groupName}.${spec.moduleName} or { };
                };

                consolidatedArgs = {
                  lib = args.lib;
                  pkgs = args.pkgs;
                  pkgs-unstable = args.pkgs-unstable;
                  funcs = args.funcs;
                  helpers = args.helpers;
                  defs = args.defs;
                  self = contextWithOptions;
                };

                moduleResult = builtins.tryEval (import spec.modulePath consolidatedArgs);

                on = if moduleResult.success then moduleResult.value.on or { } else { };
                platformOn =
                  if isLinux then
                    on.linux or { }
                  else if isDarwin then
                    on.darwin or { }
                  else
                    { };

                wrapInit = initFn: { config, ... }: initFn config;

                initFns =
                  (if on ? init then [ (wrapInit on.init) ] else [ ])
                  ++ (if platformOn ? init then [ (wrapInit platformOn.init) ] else [ ]);
              in
              initFns
            ) moduleSpecs
          )
        else
          [ ];
    in
    lib.flatten (map scanInput defs.moduleInputsToScan);
}
