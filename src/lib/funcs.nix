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
        "module"
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

  isProfileKeys = [
    "isNixOS"
    "isLinux"
    "isDarwin"
    "isX86_64"
    "isAARCH64"
    "isStandalone"
    "isIntegrated"
  ];

  validateInnerModule =
    prefix: modulePath: module:
    let
      l1FnNames = [
        "init"
        "enabled"
        "home"
        "system"
        "standalone"
        "integrated"
      ];
      l1BaseAllowed = l1FnNames ++ [ "overlays" ];
      l1CondAllowed = [
        "enabled"
        "home"
        "system"
        "standalone"
        "integrated"
      ];
      condStructuralKeys = l1CondAllowed ++ [
        "linux"
        "darwin"
        "x86_64"
        "aarch64"
      ];

      validateFn =
        path: name: value:
        if !(builtins.isFunction value) then
          [ "${prefix}.${path}${name} must be a function (config: { ... }), got ${builtins.typeOf value}" ]
        else
          [ ];

      checkInvalid =
        containerName: allowed: attrset:
        let
          invalid = builtins.filter (a: !(builtins.elem a allowed)) (builtins.attrNames attrset);
        in
        if invalid != [ ] then
          [
            "${containerName} contains invalid attributes: ${builtins.concatStringsSep ", " invalid}. Allowed: ${builtins.concatStringsSep ", " allowed}"
          ]
        else
          [ ];

      checkFns =
        pathPrefix: names: attrset:
        lib.concatMap (
          name: if attrset ? ${name} then validateFn pathPrefix name attrset.${name} else [ ]
        ) names;

      validatePlatformBase =
        pathPrefix: platName: platModule:
        checkInvalid "${prefix}.${pathPrefix}${platName}" l1BaseAllowed platModule
        ++ checkFns "${pathPrefix}${platName}." l1FnNames platModule;

      validateArchBase =
        pathPrefix: archName: archModule:
        let
          fullPath = "${pathPrefix}${archName}";
        in
        checkInvalid "${prefix}.${fullPath}" (
          l1BaseAllowed
          ++ [
            "linux"
            "darwin"
          ]
        ) archModule
        ++ checkFns "${fullPath}." l1FnNames archModule
        ++
          lib.concatMap
            (
              platName:
              if archModule ? ${platName} && builtins.isAttrs archModule.${platName} then
                validatePlatformBase "${fullPath}." platName archModule.${platName}
              else if archModule ? ${platName} then
                [
                  "${prefix}.${fullPath}.${platName} must be an attribute set, got ${
                    builtins.typeOf archModule.${platName}
                  }"
                ]
              else
                [ ]
            )
            [
              "linux"
              "darwin"
            ];

      validatePlatformCond =
        pathPrefix: platName: platModule:
        checkInvalid "${prefix}.${pathPrefix}${platName}" l1CondAllowed platModule
        ++ checkFns "${pathPrefix}${platName}." l1CondAllowed platModule;

      validateArchCond =
        pathPrefix: archName: archModule:
        let
          fullPath = "${pathPrefix}${archName}";
        in
        checkInvalid "${prefix}.${fullPath}" (
          l1CondAllowed
          ++ [
            "linux"
            "darwin"
          ]
        ) archModule
        ++ checkFns "${fullPath}." l1CondAllowed archModule
        ++
          lib.concatMap
            (
              platName:
              if archModule ? ${platName} && builtins.isAttrs archModule.${platName} then
                validatePlatformCond "${fullPath}." platName archModule.${platName}
              else if archModule ? ${platName} then
                [ "${prefix}.${fullPath}.${platName} must be an attribute set" ]
              else
                [ ]
            )
            [
              "linux"
              "darwin"
            ];

      validateCondBody =
        path: attrset:
        checkInvalid "${prefix}.${path}" condStructuralKeys attrset
        ++ checkFns "${path}." l1CondAllowed attrset
        ++
          lib.concatMap
            (
              platName:
              if attrset ? ${platName} && builtins.isAttrs attrset.${platName} then
                validatePlatformCond "${path}." platName attrset.${platName}
              else if attrset ? ${platName} then
                [ "${prefix}.${path}.${platName} must be an attribute set" ]
              else
                [ ]
            )
            [
              "linux"
              "darwin"
            ]
        ++
          lib.concatMap
            (
              archName:
              if attrset ? ${archName} && builtins.isAttrs attrset.${archName} then
                validateArchCond "${path}." archName attrset.${archName}
              else if attrset ? ${archName} then
                [ "${prefix}.${path}.${archName} must be an attribute set" ]
              else
                [ ]
            )
            [
              "x86_64"
              "aarch64"
            ];

      validateConditionalModule =
        condName: modPath: modModule:
        validateCondBody "${condName}.${modPath}" modModule;

      validateModulesField =
        path: modulesAttr:
        if !(builtins.isAttrs modulesAttr) then
          [ "${prefix}.${path}.modules must be an attrset, got ${builtins.typeOf modulesAttr}" ]
        else if modulesAttr == { } then
          [ "${prefix}.${path}.modules must not be empty" ]
        else
          lib.flatten (
            lib.mapAttrsToList (
              inputName: groups:
              if !(builtins.isAttrs groups) then
                [ "${prefix}.${path}.modules.${inputName} must be an attrset, got ${builtins.typeOf groups}" ]
              else
                lib.flatten (
                  lib.mapAttrsToList (
                    groupName: modules:
                    if builtins.isList modules then
                      let
                        nonStrings = builtins.filter (x: !(builtins.isString x)) modules;
                      in
                      if nonStrings != [ ] then
                        [ "${prefix}.${path}.modules.${inputName}.${groupName} list must contain only strings" ]
                      else
                        [ ]
                    else if builtins.isAttrs modules then
                      lib.flatten (
                        lib.mapAttrsToList (
                          moduleName: v:
                          if builtins.isBool v || builtins.isAttrs v then
                            [ ]
                          else
                            [
                              "${prefix}.${path}.modules.${inputName}.${groupName}.${moduleName} must be true, false, or an attrset of option checks"
                            ]
                        ) modules
                      )
                    else
                      [
                        "${prefix}.${path}.modules.${inputName}.${groupName} must be an attrset or list, got ${builtins.typeOf modules}"
                      ]
                  ) groups
                )
            ) modulesAttr
          );

      validatePredicateItem =
        path: item:
        if !(builtins.isAttrs item) then
          [ "${prefix}.${path} must be an attribute set, got ${builtins.typeOf item}" ]
        else
          let
            allowedKeys = [
              "condition"
              "modules"
              "host"
              "user"
              "option"
              "do"
            ]
            ++ isProfileKeys;
            unknownKeys = builtins.filter (k: !(builtins.elem k allowedKeys)) (builtins.attrNames item);
            unknownErrors =
              if unknownKeys != [ ] then
                [
                  "${prefix}.${path} has unknown fields: ${builtins.concatStringsSep ", " unknownKeys}. Allowed: ${builtins.concatStringsSep ", " allowedKeys}"
                ]
              else
                [ ];
            hasCondition = item ? condition;
            hasModules = item ? modules;
            hasHost = item ? host;
            hasUser = item ? user;
            hasOption = item ? option;
            hasIsKey = builtins.any (k: item ? ${k}) isProfileKeys;
            condErrors =
              if hasCondition && !(builtins.isFunction item.condition) then
                [
                  "${prefix}.${path}.condition must be a function (config: bool), got ${builtins.typeOf item.condition}"
                ]
              else
                [ ];
            modulesErrors = if hasModules then validateModulesField path item.modules else [ ];
            moduleChecksPresent = hasModules && builtins.isAttrs item.modules && item.modules != { };
            hostErrors =
              if hasHost && !(builtins.isAttrs item.host) then
                [ "${prefix}.${path}.host must be an attribute set, got ${builtins.typeOf item.host}" ]
              else
                [ ];
            userErrors =
              if hasUser && !(builtins.isAttrs item.user) then
                [ "${prefix}.${path}.user must be an attribute set, got ${builtins.typeOf item.user}" ]
              else
                [ ];
            optionErrors =
              if hasOption && !(builtins.isAttrs item.option) then
                [ "${prefix}.${path}.option must be an attribute set, got ${builtins.typeOf item.option}" ]
              else if hasOption && item.option == { } then
                [ "${prefix}.${path}.option must not be empty" ]
              else
                [ ];
            isValidMkNot = v: builtins.isAttrs v && v ? __nxNot;
            isKeyErrors = lib.flatten (
              map (
                k:
                if item ? ${k} && !builtins.isBool item.${k} && !(isValidMkNot item.${k}) then
                  [
                    "${prefix}.${path}.${k} must be a boolean or helpers.mkNot bool, got ${builtins.typeOf item.${k}}"
                  ]
                else
                  [ ]
              ) isProfileKeys
            );
            hasAnyCheck =
              hasCondition
              || moduleChecksPresent
              || (hasHost && builtins.isAttrs item.host)
              || (hasUser && builtins.isAttrs item.user)
              || (hasOption && builtins.isAttrs item.option && item.option != { })
              || hasIsKey;
            missingError =
              if !hasAnyCheck then
                [
                  "${prefix}.${path} must have at least one check field: condition, modules, host, user, option, or a profile flag (${builtins.concatStringsSep ", " isProfileKeys})"
                ]
              else
                [ ];
            doErrors =
              if !(item ? do) then
                [ "${prefix}.${path} is missing required 'do' field" ]
              else if !(builtins.isAttrs item.do) then
                [ "${prefix}.${path}.do must be an attribute set, got ${builtins.typeOf item.do}" ]
              else if item.do == { } then
                [
                  "${prefix}.${path}.do must not be empty. Add at least one of: ${builtins.concatStringsSep ", " condStructuralKeys}"
                ]
              else
                validateCondBody "${path}.do" item.do;
          in
          unknownErrors
          ++ condErrors
          ++ modulesErrors
          ++ hostErrors
          ++ userErrors
          ++ optionErrors
          ++ isKeyErrors
          ++ missingError
          ++ doErrors;

      validateConditional =
        condName: condModule:
        if !(builtins.isAttrs condModule) then
          [ "${prefix}.${condName} must be an attribute set" ]
        else
          lib.flatten (
            lib.mapAttrsToList (
              inputName: groups:
              if !(builtins.isAttrs groups) then
                [
                  "${prefix}.${condName}.${inputName} must be an attribute set (expected group names), got ${builtins.typeOf groups}"
                ]
              else
                lib.flatten (
                  lib.mapAttrsToList (
                    groupName: modules:
                    let
                      path2 = "${condName}.${inputName}.${groupName}";
                      shallowKeys = builtins.filter (k: builtins.elem k condStructuralKeys) (builtins.attrNames modules);
                    in
                    if !(builtins.isAttrs modules) then
                      [
                        "${prefix}.${path2} must be an attribute set (expected module names), got ${builtins.typeOf modules}"
                      ]
                    else if shallowKeys != [ ] then
                      [
                        "${prefix}.${path2} contains module-function keys (${builtins.concatStringsSep ", " shallowKeys}). Path must be INPUT.GROUP.MODULE (3 levels deep)"
                      ]
                    else
                      lib.flatten (
                        lib.mapAttrsToList (
                          moduleName: subModule:
                          if !(builtins.isAttrs subModule) then
                            [ "${prefix}.${path2}.${moduleName} must be an attribute set" ]
                          else
                            validateConditionalModule condName "${inputName}.${groupName}.${moduleName}" subModule
                        ) modules
                      )
                  ) groups
                )
            ) condModule
          );

      topAllowed = l1BaseAllowed ++ [
        "linux"
        "darwin"
        "x86_64"
        "aarch64"
        "ifEnabled"
        "ifDisabled"
        "when"
      ];

      topErrors = checkInvalid "on" topAllowed module;
      topFnErrors = checkFns "" l1FnNames module;

      platErrors =
        lib.concatMap
          (
            platName:
            if module ? ${platName} && builtins.isAttrs module.${platName} then
              validatePlatformBase "" platName module.${platName}
            else if module ? ${platName} then
              [ "${prefix}.${platName} must be an attribute set, got ${builtins.typeOf module.${platName}}" ]
            else
              [ ]
          )
          [
            "linux"
            "darwin"
          ];

      archErrors =
        lib.concatMap
          (
            archName:
            if module ? ${archName} && builtins.isAttrs module.${archName} then
              validateArchBase "" archName module.${archName}
            else if module ? ${archName} then
              [ "${prefix}.${archName} must be an attribute set, got ${builtins.typeOf module.${archName}}" ]
            else
              [ ]
          )
          [
            "x86_64"
            "aarch64"
          ];

      conditionalErrors =
        (if module ? ifEnabled then validateConditional "ifEnabled" module.ifEnabled else [ ])
        ++ (if module ? ifDisabled then validateConditional "ifDisabled" module.ifDisabled else [ ]);

      whenErrors =
        if module ? when then
          let
            val = module.when;
          in
          if builtins.isList val then
            if val == [ ] then
              [ "${prefix}.when must not be an empty list" ]
            else
              lib.flatten (lib.imap0 (i: item: validatePredicateItem "when[${toString i}]" item) val)
          else if builtins.isAttrs val then
            validatePredicateItem "when" val
          else
            [
              "${prefix}.when must be a predicate attrset or a list of predicate attrsets, got ${builtins.typeOf val}"
            ]
        else
          [ ];

      allErrors = topErrors ++ topFnErrors ++ platErrors ++ archErrors ++ conditionalErrors ++ whenErrors;
    in
    if allErrors != [ ] then
      throw "Module ${modulePath} has invalid 'on' configuration:\n  ${builtins.concatStringsSep "\n  " allErrors}"
    else
      module;

  selectApplicableModuleFns =
    {
      prefix,
      module,
      buildContext,
      architecture,
      includeInit ? false,
      sourceModule ? "unknown",
      moduleNxPath ? null,
    }:
    let
      isLinux = helpers.isLinuxArch architecture;
      isDarwin = helpers.isDarwinArch architecture;
      isX86_64 = helpers.isX86_64Arch architecture;
      isAARCH64 = helpers.isAARCH64Arch architecture;

      isHome = buildContext == "home-standalone" || buildContext == "home-integrated";
      isStandalone = buildContext == "home-standalone";
      isIntegrated = buildContext == "home-integrated";

      tag = fn: type: wrap: { inherit fn type wrap; };

      platformOf =
        attrset:
        if isLinux then
          attrset.linux or { }
        else if isDarwin then
          attrset.darwin or { }
        else
          { };

      archOf =
        attrset:
        if isX86_64 then
          attrset.x86_64 or { }
        else if isAARCH64 then
          attrset.aarch64 or { }
        else
          { };

      collectL1 =
        excludeInit: wrap: attrset:
        lib.optional (!excludeInit && includeInit && attrset ? init) (tag attrset.init "init" wrap)
        ++ lib.optional (attrset ? enabled) (tag attrset.enabled "enabled" wrap)
        ++ lib.optional (isHome && attrset ? home) (tag attrset.home "home" wrap)
        ++ lib.optional (isHome && isStandalone && attrset ? standalone) (
          tag attrset.standalone "standalone" wrap
        )
        ++ lib.optional (isHome && isIntegrated && attrset ? integrated) (
          tag attrset.integrated "integrated" wrap
        )
        ++ lib.optional (!isHome && attrset ? system) (tag attrset.system "system" wrap);

      collectLayers123 =
        excludeInit: wrap: attrset:
        let
          platModule = platformOf attrset;
          archModule = archOf attrset;
          archPlatModule = platformOf archModule;
        in
        collectL1 excludeInit wrap attrset
        ++ collectL1 excludeInit wrap platModule
        ++ collectL1 excludeInit wrap archModule
        ++ collectL1 excludeInit wrap archPlatModule;

      makeWrap =
        isEnabled: modulePath:
        let
          pathParts = lib.splitString "." modulePath;
          enablePath = [ "nx" ] ++ pathParts ++ [ "enable" ];
          condName = if isEnabled then "ifEnabled" else "ifDisabled";
        in
        fn: config:
        lib.mkIf (
          let
            enableValue =
              lib.attrByPath enablePath (throw "${sourceModule}: ${condName}: module '${modulePath}' not found")
                config;
            checkedValue =
              if !builtins.isBool enableValue then
                throw "${sourceModule}: ${condName}: config.nx.${modulePath}.enable must be a boolean, got ${builtins.typeOf enableValue}"
              else
                enableValue;
          in
          if isEnabled then checkedValue else !checkedValue
        ) (fn config);

      collectConditional =
        isEnabled: condAttrsets:
        lib.flatten (
          lib.mapAttrsToList (
            inputName: groups:
            lib.flatten (
              lib.mapAttrsToList (
                groupName: modules:
                lib.flatten (
                  lib.mapAttrsToList (
                    moduleName: subModule:
                    collectLayers123 true (makeWrap isEnabled "${inputName}.${groupName}.${moduleName}") subModule
                  ) modules
                )
              ) groups
            )
          ) condAttrsets
        );
      makePredWrap =
        label: condition: fn: config:
        lib.mkIf (
          let
            result = condition config;
          in
          if !builtins.isBool result then
            throw "${sourceModule}: ${prefix}.${label}: condition must return a boolean, got ${builtins.typeOf result}"
          else
            result
        ) (fn config);

      flattenAttrs =
        prefix: attrs:
        lib.flatten (
          lib.mapAttrsToList (
            k: v:
            if builtins.isAttrs v && !(v ? __nxNot) then
              flattenAttrs (prefix ++ [ k ]) v
            else
              [
                {
                  path = prefix ++ [ k ];
                  expected = v;
                }
              ]
          ) attrs
        );

      parseModuleChecks =
        modulesAttr:
        lib.flatten (
          lib.mapAttrsToList (
            inputName: groups:
            lib.flatten (
              lib.mapAttrsToList (
                groupName: modules:
                if builtins.isList modules then
                  map (moduleName: {
                    path = [
                      inputName
                      groupName
                      moduleName
                    ];
                    type = "enable";
                    required = true;
                  }) modules
                else
                  lib.mapAttrsToList (
                    moduleName: value:
                    if builtins.isBool value then
                      {
                        path = [
                          inputName
                          groupName
                          moduleName
                        ];
                        type = "enable";
                        required = value;
                      }
                    else
                      {
                        path = [
                          inputName
                          groupName
                          moduleName
                        ];
                        type = "options";
                        optionPairs = flattenAttrs [ ] value;
                      }
                  ) modules
              ) groups
            )
          ) modulesAttr
        );

      buildItemCondition =
        label: item:
        let
          condition = item.condition or null;
          moduleChecks = if item ? modules then parseModuleChecks item.modules else [ ];
          requireAttrByPath =
            context: fullPathStr: remainingPath: obj:
            if remainingPath == [ ] then
              obj
            else if !builtins.isAttrs obj then
              throw "${sourceModule}: ${prefix}.${label}.${context}: path '${fullPathStr}' does not exist"
            else if !(obj ? ${builtins.head remainingPath}) then
              throw "${sourceModule}: ${prefix}.${label}.${context}: path '${fullPathStr}' does not exist"
            else
              requireAttrByPath context fullPathStr (builtins.tail remainingPath)
                obj.${builtins.head remainingPath};
          compareValues =
            context: pathStr: actual: expected:
            let
              isNot = builtins.isAttrs expected && expected ? __nxNot;
              checkVal = if isNot then expected.value else expected;
              result =
                if actual == null || checkVal == null then
                  actual == checkVal
                else if builtins.typeOf actual != builtins.typeOf checkVal then
                  throw "${sourceModule}: ${prefix}.${label}.${context}: path '${pathStr}' is of type '${builtins.typeOf actual}' but check value has type '${builtins.typeOf checkVal}'"
                else
                  actual == checkVal;
            in
            if isNot then !result else result;
          hostChecks = if item ? host then flattenAttrs [ ] item.host else [ ];
          userChecks = if item ? user then flattenAttrs [ ] item.user else [ ];
          optionChecks = if item ? option then flattenAttrs [ ] item.option else [ ];
          isChecks = builtins.filter (k: item ? ${k}) isProfileKeys;
        in
        config:
        (if condition != null then condition config else true)
        && lib.all (
          check:
          let
            modulePath = builtins.concatStringsSep "." check.path;
          in
          if check.type == "enable" then
            let
              v = lib.attrByPath (
                [ "nx" ] ++ check.path ++ [ "enable" ]
              ) (throw "${sourceModule}: ${prefix}.${label}.modules: module '${modulePath}' not found") config;
            in
            if check.required then v else !v
          else
            lib.all (
              { path, expected }:
              let
                fullPath = [ "nx" ] ++ check.path ++ path;
                pathStr = modulePath + "." + builtins.concatStringsSep "." path;
                actual =
                  lib.attrByPath fullPath
                    (throw "${sourceModule}: ${prefix}.${label}.modules.${modulePath}: option '${builtins.concatStringsSep "." path}' not found")
                    config;
              in
              compareValues "modules.${modulePath}" pathStr actual expected
            ) check.optionPairs
        ) moduleChecks
        && (
          if hostChecks == [ ] then
            true
          else
            let
              hostVal = config.nx.profile.host;
            in
            if hostVal == null then
              false
            else
              lib.all (
                { path, expected }:
                let
                  pathStr = builtins.concatStringsSep "." path;
                  actual = requireAttrByPath "host" pathStr path hostVal;
                in
                compareValues "host" pathStr actual expected
              ) hostChecks
        )
        && (
          if userChecks == [ ] then
            true
          else
            let
              userVal = config.nx.profile.user;
            in
            if userVal == null then
              false
            else
              lib.all (
                { path, expected }:
                let
                  pathStr = builtins.concatStringsSep "." path;
                  actual = requireAttrByPath "user" pathStr path userVal;
                in
                compareValues "user" pathStr actual expected
              ) userChecks
        )
        && (
          if optionChecks == [ ] then
            true
          else if moduleNxPath == null then
            throw "${sourceModule}: ${prefix}.${label}.option: option checks are not available in this context"
          else
            lib.all (
              { path, expected }:
              let
                fullPath = [ "nx" ] ++ moduleNxPath ++ path;
                pathStr = builtins.concatStringsSep "." (moduleNxPath ++ path);
                actual =
                  lib.attrByPath fullPath
                    (throw "${sourceModule}: ${prefix}.${label}.option: path '${pathStr}' does not exist")
                    config;
              in
              compareValues "option" pathStr actual expected
            ) optionChecks
        )
        && lib.all (
          k:
          let
            actual = config.nx.profile.${k};
            expected = item.${k};
            isNot = builtins.isAttrs expected && expected ? __nxNot;
            checkVal = if isNot then expected.value else expected;
            result = actual == checkVal;
          in
          if isNot then !result else result
        ) isChecks;

      whenFns =
        let
          collect =
            label: item:
            collectLayers123 true (makePredWrap label (buildItemCondition label item)) (item.do or { });
          val = module.when or null;
        in
        if val == null then
          [ ]
        else if builtins.isList val then
          lib.flatten (lib.imap0 (i: item: collect "when[${toString i}]" item) val)
        else if builtins.isAttrs val then
          collect "when" val
        else
          [ ];
    in
    collectLayers123 false null module
    ++ collectConditional true (module.ifEnabled or { })
    ++ collectConditional false (module.ifDisabled or { })
    ++ whenFns;

  mergeModuleFunctions =
    prefix: moduleIdentifier: moduleNxPath: fns:
    if fns == [ ] then
      { }
    else
      { config, ... }:
      let
        contextSpecific = [
          "home"
          "system"
          "integrated"
          "standalone"
        ];
        normalizeStyle =
          fn:
          if moduleNxPath != null && builtins.functionArgs fn != { } then
            let
              moduleArgNames = builtins.filter (a: a != "config") (builtins.attrNames (builtins.functionArgs fn));
            in
            c:
            fn (
              {
                config = c;
              }
              // lib.genAttrs moduleArgNames (name: (lib.attrByPath ([ "nx" ] ++ moduleNxPath) { } c).${name})
            )
          else
            fn;
        callAndValidate =
          {
            fn,
            type,
            wrap ? null,
          }:
          let
            isNewStyle = moduleNxPath != null && builtins.functionArgs fn != { };
            normalizedFn =
              if builtins.elem type contextSpecific then
                normalizeStyle fn
              else if isNewStyle then
                throw "Module ${moduleIdentifier}: the { config, opt, ... } signature is disallowed for ${prefix}.${type}. Use ${prefix}.${type} = config: { ... } and access options via config.nx directly."
              else
                fn;
            result = (if wrap != null then wrap normalizedFn else normalizedFn) config;
          in
          if (result ? nx) && (builtins.elem type contextSpecific) then
            throw "Module ${moduleIdentifier}: nx.* options cannot be set in ${prefix}.${type}.\n\nUse ${prefix}.init or ${prefix}.enabled for shared options!"
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

      module = validateInnerModule "prefix" modulePath (moduleResult.module or { });
      architecture = resolveArchitecture args;

      applicableFns = selectApplicableModuleFns {
        inherit module buildContext architecture;
        prefix = "module";
        sourceModule = toString modulePath;
        moduleNxPath = [
          moduleSpec.inputName
          moduleSpec.group
          moduleSpec.name
        ];
      };

      configFn = mergeModuleFunctions "module" (toString modulePath) [
        moduleSpec.inputName
        moduleSpec.group
        moduleSpec.name
      ] applicableFns;
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

  processProfileModule =
    {
      profile,
      profileType,
      profileName,
      args,
      processedModules,
      buildContext,
    }:
    let
      module = validateInnerModule "profile" "profile:${profileType}/${profileName}" (
        profile.profile or { }
      );
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

      allFns = selectApplicableModuleFns {
        inherit module buildContext architecture;
        prefix = "profile";
        includeInit = true;
        sourceModule = "profile:${profileType}/${profileName}";
      };

      applyArgs =
        {
          fn,
          type,
          wrap ? null,
        }:
        {
          fn = (config: fn enhancedArgs config);
          inherit type wrap;
        };

      appliedFns = map applyArgs allFns;
      initFns = builtins.filter (f: f.type == "init") appliedFns;
      contextFns = builtins.filter (f: f.type != "init") appliedFns;
    in
    {
      initModules =
        if initFns == [ ] then
          [ ]
        else
          [ (mergeModuleFunctions "profile" "profile:${profileType}/${profileName}" null initFns) ];

      contextModules =
        if contextFns == [ ] then
          [ ]
        else
          [ (mergeModuleFunctions "profile" "profile:${profileType}/${profileName}" null contextFns) ];
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

  extractOverlaysFromModule =
    { module, system }:
    let
      isLinux = helpers.isLinuxArch system;
      isDarwin = helpers.isDarwinArch system;
      isX86_64 = helpers.isX86_64Arch system;
      isAARCH64 = helpers.isAARCH64Arch system;
      platModule =
        if isLinux then
          module.linux or { }
        else if isDarwin then
          module.darwin or { }
        else
          { };
      archModule =
        if isX86_64 then
          module.x86_64 or { }
        else if isAARCH64 then
          module.aarch64 or { }
        else
          { };
      archPlatModule =
        if isLinux then
          archModule.linux or { }
        else if isDarwin then
          archModule.darwin or { }
        else
          { };
    in
    (module.overlays or [ ])
    ++ (platModule.overlays or [ ])
    ++ (archModule.overlays or [ ])
    ++ (archPlatModule.overlays or [ ]);

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
              extractOverlaysFromModule {
                module = moduleResult.value.module or { };
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

                module = if moduleResult.success then moduleResult.value.module or { } else { };

                wrapInit = initFn: { config, ... }: initFn config;

                initFns = map (f: wrapInit f.fn) (
                  builtins.filter (f: f.type == "init") (selectApplicableModuleFns {
                    inherit module architecture;
                    prefix = "module";
                    buildContext = "system";
                    includeInit = true;
                    sourceModule = toString spec.modulePath;
                  })
                );
              in
              initFns
            ) moduleSpecs
          )
        else
          [ ];
    in
    lib.flatten (map scanInput defs.moduleInputsToScan);
}
