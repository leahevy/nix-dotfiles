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
      moduleType,
    }:
    input + "/modules/${moduleType}/${group}/${name}/${name}.nix";
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
    if moduleIndex == null || moduleIndex + 3 >= builtins.length parts then
      null
    else
      let
        namespace = builtins.elemAt parts (moduleIndex + 1);
        group = builtins.elemAt parts (moduleIndex + 2);
        module = builtins.elemAt parts (moduleIndex + 3);

        expectedFilename = "${module}.nix";
        actualFilename = builtins.baseNameOf pathStr;
      in
      if actualFilename == expectedFilename then { inherit namespace group module; } else null;

  validateModule =
    moduleResult: filePath: moduleContext:
    let
      correctFormat = builtins.isAttrs moduleResult && !builtins.isFunction moduleResult;

      approvedAttrs = [
        "name"
        "description"
        "group"
        "input"
        "namespace"
        "submodules"
        "settings"
        "assertions"
        "custom"
        "configuration"
        "unfree"
        "warning"
        "error"
        "broken"
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
            "Could not extract path components from module path. Ensure module is in correct location: modules/NAMESPACE/GROUP/MODULE/MODULE.nix"
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

            namespaceError =
              if !(moduleResult ? namespace) then
                "Module missing required 'namespace' field"
              else if moduleResult.namespace != pathComponents.namespace then
                "Module namespace '${moduleResult.namespace}' does not match path '${pathComponents.namespace}'"
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
            namespaceError
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
    in
    if !correctFormat then
      throw formatErrorMessage
    else if nameValidationError != null then
      throw "${filePath}: ${nameValidationError}"
    else if pathValidationErrors != [ ] then
      throw pathErrorMessage
    else if invalidAttrs != [ ] then
      throw topLevelErrorMessage
    else
      let
        moduleWarning = moduleResult.warning or null;
        moduleError = moduleResult.error or null;
        moduleBroken = moduleResult.broken or false;

        getCleanPath =
          _:
          let
            pathStr = toString filePath;
            parts = lib.splitString "/" pathStr;
            moduleIndex = lib.findFirst (i: builtins.elemAt parts i == "modules") null (
              lib.range 0 (builtins.length parts - 1)
            );
          in
          if moduleIndex != null && moduleIndex + 3 < builtins.length parts then
            let
              group = builtins.elemAt parts (moduleIndex + 2);
              module = builtins.elemAt parts (moduleIndex + 3);
            in
            "${group}.${module}"
          else
            lib.removeSuffix ".nix" (builtins.baseNameOf pathStr);
      in
      if moduleError != null then
        throw "${getCleanPath null}: ${moduleError}"
      else if moduleBroken then
        throw "${getCleanPath null}: This module is currently broken!"
      else if moduleWarning != null then
        builtins.trace "${getCleanPath null}: ${moduleWarning}" moduleResult
      else
        moduleResult;

  mergeModuleDefaults =
    lib: helpers: args: moduleType: inputName: groupName: moduleName: moduleSettings:
    let
      modulePath =
        helpers.resolveInputFromInput inputName
        + "/modules/${moduleType}/${groupName}/${moduleName}/${moduleName}.nix";
    in
    if !builtins.pathExists modulePath then
      if moduleSettings == true then { } else moduleSettings
    else
      let
        moduleDir = "modules/${moduleType}/${groupName}/${moduleName}";

        moduleContext = {
          inputs = args.inputs;
          variables = args.variables;
          configInputs = args.configInputs or { };
          moduleBasePath = moduleDir;
          moduleInput = helpers.resolveInputFromInput inputName;
          moduleInputName = inputName;
          settings = { };
        }
        // (
          if moduleType == "home" then
            {
              host = args.host;
              user = args.user;
            }
          else
            {
              host = args.host;
              users = args.users;
            }
        );

        enhancedModuleContext = injectModuleFuncs moduleContext moduleType;

        moduleResult = import modulePath {
          lib = args.lib;
          pkgs = args.pkgs;
          pkgs-unstable = args.pkgs-unstable;
          funcs = args.funcs;
          helpers = helpers;
          defs = args.defs;
          self = enhancedModuleContext;
        };

        moduleDefaults = moduleResult.settings or { };
        moduleUnfree = moduleResult.unfree or [ ];

        userSettings = if moduleSettings == true then { } else moduleSettings;

        settingsWithUnfree =
          if moduleUnfree != [ ] then userSettings // { unfree = moduleUnfree; } else userSettings;
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
    moduleContext: moduleType:
    let
      appliedCommonFuncs = lib.mapAttrs (name: func: func moduleContext) moduleFuncs.commonFuncs;

      contextFuncs =
        if moduleType == "home" then
          {
            user = moduleContext.user // (lib.mapAttrs (name: func: func moduleContext) moduleFuncs.userFuncs);
          }
        else
          {
            host = moduleContext.host // (lib.mapAttrs (name: func: func moduleContext) moduleFuncs.hostFuncs);
          };

      hierarchicalFuncs = moduleFuncs.hierarchicalInputFuncs moduleContext moduleContext.moduleBasePath;

      persistShortcut =
        if moduleType == "home" then
          {
            persist = "${moduleContext.variables.persist.home}/${moduleContext.user.username}";
          }
        else
          {
            persist = moduleContext.variables.persist.system;
          };
    in
    moduleContext // appliedCommonFuncs // contextFuncs // hierarchicalFuncs // persistShortcut;

  importHomeModule =
    args: moduleSpec: allProcessedModules:
    let
      modulePath = buildModulePath {
        input = moduleSpec.input;
        group = moduleSpec.group;
        name = moduleSpec.name;
        moduleType = "home";
      };
      moduleDir = "modules/home/${moduleSpec.group}/${moduleSpec.name}";

      basicModuleResult = import modulePath {
        lib = args.lib;
        pkgs = args.pkgs;
        pkgs-unstable = args.pkgs-unstable;
        funcs = args.funcs;
        helpers = helpers;
        defs = args.defs;
        self = { };
      };

      moduleContext = {
        inputs = args.inputs;
        host = args.host // {
          processedModules = args.systemProcessedModules or { };
        };
        user = args.user // {
          processedModules = allProcessedModules;
        };
        variables = args.variables;
        configInputs = args.configInputs or { };
        moduleBasePath = moduleDir;
        moduleInput = moduleSpec.input;
        moduleInputName = moduleSpec.inputName;
        settings = moduleSpec.settings or { };
        unfree = basicModuleResult.unfree or [ ];
      };

      enhancedModuleContext = injectModuleFuncs moduleContext "home";

      consolidatedArgs = {
        lib = args.lib;
        pkgs = args.pkgs;
        pkgs-unstable = args.pkgs-unstable;
        funcs = args.funcs;
        helpers = helpers;
        defs = args.defs;
        self = enhancedModuleContext;
      };
    in
    let
      moduleResult = validateModule (import modulePath consolidatedArgs) modulePath {
        inputName = moduleSpec.inputName;
      };

    in
    {
      configuration = if moduleResult ? configuration then moduleResult.configuration else (context: { });
      submodules = moduleResult.submodules or { };
    };

  importSystemModule =
    args: moduleSpec: allProcessedModules:
    let
      modulePath = buildModulePath {
        input = moduleSpec.input;
        group = moduleSpec.group;
        name = moduleSpec.name;
        moduleType = "system";
      };
      moduleDir = "modules/system/${moduleSpec.group}/${moduleSpec.name}";

      basicModuleResult = import modulePath {
        lib = args.lib;
        pkgs = args.pkgs;
        pkgs-unstable = args.pkgs-unstable;
        funcs = args.funcs;
        helpers = helpers;
        defs = args.defs;
        self = { };
      };

      moduleContext = {
        inputs = args.inputs;
        host = args.host // {
          processedModules = allProcessedModules;
        };
        users = args.users;
        user =
          if args.user or null != null then
            args.user // { processedModules = args.homeProcessedModules or { }; }
          else
            null;
        variables = args.variables;
        configInputs = args.configInputs or { };
        moduleBasePath = moduleDir;
        moduleInput = moduleSpec.input;
        moduleInputName = moduleSpec.inputName;
        settings = moduleSpec.settings or { };
        unfree = basicModuleResult.unfree or [ ];
      };

      enhancedModuleContext = injectModuleFuncs moduleContext "system";

      consolidatedArgs = {
        lib = args.lib;
        pkgs = args.pkgs;
        pkgs-unstable = args.pkgs-unstable;
        funcs = args.funcs;
        helpers = helpers;
        defs = args.defs;
        self = enhancedModuleContext;
      };
    in
    let
      moduleResult = validateModule (import modulePath consolidatedArgs) modulePath {
        inputName = moduleSpec.inputName;
      };
    in
    {
      configuration = if moduleResult ? configuration then moduleResult.configuration else (context: { });
      submodules = moduleResult.submodules or { };
    };

  importHomeModules =
    args: moduleSpecs: allProcessedModules:
    let
      moduleResults = map (spec: importHomeModule args spec allProcessedModules) moduleSpecs;
    in
    {
      modules = map (result: result.configuration) moduleResults;
      submodules = lib.foldl lib.recursiveUpdate { } (map (result: result.submodules) moduleResults);
    };

  importSystemModules =
    args: moduleSpecs: allProcessedModules:
    let
      moduleResults = map (spec: importSystemModule args spec allProcessedModules) moduleSpecs;
    in
    {
      modules = map (result: result.configuration) moduleResults;
      submodules = lib.foldl lib.recursiveUpdate { } (map (result: result.submodules) moduleResults);
    };

  collectModuleAssertions =
    args: processedModules: moduleType:
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
                    moduleType = moduleType;
                  };
                  moduleResult = import modulePath {
                    lib = args.lib;
                    pkgs = args.pkgs;
                    pkgs-unstable = args.pkgs-unstable;
                    funcs = args.funcs;
                    helpers = helpers;
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
                    moduleType = moduleType;
                  }
                ) (moduleResult.assertions or [ ])
              ) groupModules
            ) inputGroups
          ) modules
        );
    in
    collectFromModules processedModules;

  evaluateModuleAssertions =
    args: moduleType: moduleContext: assertion:
    let
      fullModuleContext = {
        inputs = args.inputs;
        host = args.host // {
          processedModules = moduleContext.systemModules;
        };
        user =
          if args ? user then
            args.user // { processedModules = moduleContext.homeModules; }
          else if args ? host && args.host ? mainUser then
            args.host.mainUser // { processedModules = moduleContext.homeModules; }
          else
            null;
        users = args.users or null;
        variables = args.variables;
        configInputs = args.configInputs or { };
        moduleBasePath = "modules/${assertion.moduleType}/${assertion.moduleSpec.group}/${assertion.moduleSpec.name}";
        moduleInput = assertion.moduleSpec.input;
        moduleInputName = assertion.moduleSpec.inputName;
        settings = assertion.moduleSpec.settings;
      };

      enhancedContext = injectModuleFuncs fullModuleContext assertion.moduleType;

      consolidatedArgs = {
        lib = args.lib;
        pkgs = args.pkgs;
        pkgs-unstable = args.pkgs-unstable;
        funcs = args.funcs;
        helpers = helpers;
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
      message = "Module ${assertion.moduleSpec.inputName}.${assertion.moduleSpec.group}.${assertion.moduleSpec.name} (namespace: ${moduleType}) assertion failed: ${targetAssertion.message}";
    };

  collectSubModules =
    args: moduleSpecs: moduleType:
    let
      moduleResults = map (
        moduleSpec:
        let
          modulePath = buildModulePath {
            input = moduleSpec.input;
            group = moduleSpec.group;
            name = moduleSpec.name;
            moduleType = moduleType;
          };
          moduleDir = "modules/${moduleType}/${moduleSpec.group}/${moduleSpec.name}";

          moduleContext = {
            inputs = args.inputs or args.self.inputs;
            variables = args.variables or args.self.variables;
            configInputs = args.configInputs or args.self.configInputs or { };
            moduleBasePath = moduleDir;
            moduleInput = moduleSpec.input;
            moduleInputName = moduleSpec.inputName;
            settings = moduleSpec.settings or { };
          }
          // (
            if moduleType == "home" then
              {
                host = args.host or args.self.host;
                user = args.user or args.self.user;
              }
            else
              {
                host = args.host or args.self.host;
                users = args.users or args.self.users;
              }
          );

          enhancedModuleContext = injectModuleFuncs moduleContext moduleType;

          consolidatedArgs = {
            lib = args.lib;
            pkgs = args.pkgs;
            pkgs-unstable = args.pkgs-unstable;
            funcs = args.funcs;
            helpers = helpers;
            defs = args.defs;
            self = enhancedModuleContext;
          };

          moduleResult = import modulePath consolidatedArgs;
        in
        let
          rawSubmodules = moduleResult.submodules or { };
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

  mergeModulesWithPrecedence =
    modules1: modules2:
    lib.zipAttrsWith
      (
        path: values:
        if builtins.length values == 1 then
          let
            value = builtins.head values;
          in
          if value == true then { } else value
        else
          builtins.foldl' mergeModuleValue (builtins.head values) (builtins.tail values)
      )
      [
        modules1
        modules2
      ];

  collectAllModulesWithSettings =
    args: initialModules: moduleType:
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
              mergeModuleDefaults lib helpers args moduleType inputName groupName moduleName moduleSettings
            ) groupModules
          ) inputGroups
        ) modules;

      buildModules =
        if moduleType == "system" then
          {
            groups = {
              build = {
                nixos = true;
              };
            };
          }
        else if moduleType == "home" then
          if (args ? user && args.user.isStandalone or false) then
            {
              groups = {
                build = {
                  home-standalone = true;
                };
              };
            }
          else
            {
              groups = {
                build = {
                  home-integrated = true;
                };
              };
            }
        else
          { };

      modulesWithBuild = lib.recursiveUpdate initialModules buildModules;

      filteredInitialModules = filterFalseValues modulesWithBuild;
      normalizedInitialModules = normalizeModules filteredInitialModules;

      collectRound =
        processedModules: currentModules: iteration:
        let
          moduleSpecs = processModules currentModules;
          collectedSubmodules = collectSubModules args moduleSpecs moduleType;
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
              lib.mapAttrsToList (moduleName: moduleSettings: moduleSettings.unfree or [ ]) groupModules
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

  applyNixOSHooks = args: import (additionalInputs.build + "/hooks/system/nixos.nix") args;

  applyIntegratedUserHooks =
    args: import (additionalInputs.build + "/hooks/home/home-integrated.nix") args;

  applyStandaloneUserHooks =
    args: import (additionalInputs.build + "/hooks/home/home-standalone.nix") args;

  findCorrespondingModules =
    sourceModules: targetNamespace: args:
    let
      getAvailableModules =
        modules:
        lib.flatten (
          lib.mapAttrsToList (
            inputName: inputGroups:
            lib.mapAttrsToList (
              groupName: groupModules:
              lib.mapAttrsToList (
                moduleName: _:
                let
                  moduleType = if targetNamespace == "home" then "home" else "system";
                  modulePath = buildModulePath {
                    input = helpers.resolveInputFromInput inputName;
                    group = groupName;
                    name = moduleName;
                    moduleType = moduleType;
                  };
                in
                if builtins.pathExists modulePath then
                  {
                    inherit inputName groupName moduleName;
                  }
                else
                  null
              ) groupModules
            ) inputGroups
          ) modules
        );

      availableTargetModules = builtins.filter (x: x != null) (getAvailableModules sourceModules);

      correspondingModules = builtins.filter (
        targetModule:
        let
          sourceModulePath = buildModulePath {
            input = helpers.resolveInputFromInput targetModule.inputName;
            group = targetModule.groupName;
            name = targetModule.moduleName;
            moduleType = if targetNamespace == "home" then "system" else "home";
          };
        in
        builtins.pathExists sourceModulePath
      ) availableTargetModules;
    in
    correspondingModules;

  addCrossNamespaceModules =
    modules: otherNamespaceModules: moduleType: args:
    let
      shouldApplyForcing = if moduleType == "home" then !(args.user.isStandalone or false) else true;

      targetNamespace = if moduleType == "home" then "home" else "system";
    in
    if !shouldApplyForcing then
      modules
    else
      let
        correspondingModules = findCorrespondingModules otherNamespaceModules targetNamespace args;

        forcedModuleSpecs = lib.foldl lib.recursiveUpdate { } (
          map (
            moduleInfo:
            let
              inputName = moduleInfo.inputName;
              groupName = moduleInfo.groupName;
              moduleName = moduleInfo.moduleName;
              moduleAlreadyExists =
                modules ? ${inputName}
                && modules.${inputName} ? ${groupName}
                && modules.${inputName}.${groupName} ? ${moduleName};
            in
            if moduleAlreadyExists then
              { }
            else
              let
                moduleDefaults =
                  let
                    modulePath = buildModulePath {
                      input = helpers.resolveInputFromInput inputName;
                      group = groupName;
                      name = moduleName;
                      moduleType = targetNamespace;
                    };
                    moduleDir = "modules/${targetNamespace}/${groupName}/${moduleName}";
                    moduleContext = {
                      inputs = args.inputs;
                      variables = args.variables;
                      configInputs = args.configInputs or { };
                      moduleBasePath = moduleDir;
                      moduleInput = helpers.resolveInputFromInput inputName;
                      moduleInputName = inputName;
                    }
                    // (
                      if targetNamespace == "home" then
                        {
                          user = args.user;
                          users = args.users;
                        }
                      else
                        {
                          host = args.host;
                          users = args.users;
                        }
                    );
                    enhancedModuleContext = moduleFuncs.injectModuleFunctions moduleContext targetNamespace;
                    moduleResult = import modulePath {
                      lib = args.lib;
                      pkgs = args.pkgs;
                      pkgs-unstable = args.pkgs-unstable;
                      funcs = args.funcs;
                      helpers = helpers;
                      defs = args.defs;
                      self = enhancedModuleContext;
                    };
                  in
                  moduleResult.settings or { };
              in
              {
                ${inputName} = {
                  ${groupName} = {
                    ${moduleName} = moduleDefaults;
                  };
                };
              }
          ) correspondingModules
        );

        mergedModules = mergeModulesWithPrecedence modules forcedModuleSpecs;
      in
      mergedModules;
}
