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

  validateModule =
    moduleResult: filePath:
    let
      correctFormat = builtins.isAttrs moduleResult && !builtins.isFunction moduleResult;

      approvedAttrs = [
        "name"
        "description"
        "submodules"
        "defaults"
        "assertions"
        "custom"
        "configuration"
        "unfree"
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
    in
    if !correctFormat then
      throw formatErrorMessage
    else if nameValidationError != null then
      throw "${filePath}: ${nameValidationError}"
    else if invalidAttrs != [ ] then
      throw topLevelErrorMessage
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

        moduleDefaults = moduleResult.defaults or { };
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
    args: moduleSpec:
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
        host = args.host;
        user = args.user;
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
      moduleResult = validateModule (import modulePath consolidatedArgs) modulePath;

      assertions = moduleResult.assertions or [ ];
      validationErrors = builtins.filter (assertion: !(assertion.assertion or true)) assertions;
    in
    if validationErrors != [ ] then
      throw "Module ${moduleSpec.inputName}.${moduleSpec.group}.${moduleSpec.name} assertion failed: ${(builtins.head validationErrors).message}"
    else
      {
        configuration = if moduleResult ? configuration then moduleResult.configuration else (context: { });
        submodules = moduleResult.submodules or { };
      };

  importSystemModule =
    args: moduleSpec:
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
        host = args.host;
        users = args.users;
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
      moduleResult = validateModule (import modulePath consolidatedArgs) modulePath;

      assertions = moduleResult.assertions or [ ];
      validationErrors = builtins.filter (assertion: !(assertion.assertion or true)) assertions;
    in
    if validationErrors != [ ] then
      throw "Module ${moduleSpec.inputName}.${moduleSpec.group}.${moduleSpec.name} assertion failed: ${(builtins.head validationErrors).message}"
    else
      {
        configuration = if moduleResult ? configuration then moduleResult.configuration else (context: { });
        submodules = moduleResult.submodules or { };
      };

  importHomeModules =
    args: moduleSpecs:
    let
      moduleResults = map (spec: importHomeModule args spec) moduleSpecs;
    in
    {
      modules = map (result: result.configuration) moduleResults;
      submodules = lib.foldl lib.recursiveUpdate { } (map (result: result.submodules) moduleResults);
    };

  importSystemModules =
    args: moduleSpecs:
    let
      moduleResults = map (spec: importSystemModule args spec) moduleSpecs;
    in
    {
      modules = map (result: result.configuration) moduleResults;
      submodules = lib.foldl lib.recursiveUpdate { } (map (result: result.submodules) moduleResults);
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

      filteredInitialModules = filterFalseValues initialModules;
      normalizedInitialModules = normalizeModules filteredInitialModules;
      initialModulesWithDefaults = applyDefaultsToModules normalizedInitialModules;

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
    collectRound { } initialModulesWithDefaults 0;

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
}
