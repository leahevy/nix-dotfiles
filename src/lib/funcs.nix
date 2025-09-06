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
  validateModule =
    moduleResult: filePath:
    let
      correctFormat = builtins.isAttrs moduleResult && !builtins.isFunction moduleResult;

      approvedAttrs = [
        "meta"
        "submodules"
        "defaults"
        "assertions"
        "custom"
        "configuration"
      ];

      actualAttrs = builtins.attrNames moduleResult;

      invalidAttrs = builtins.filter (attr: !(builtins.elem attr approvedAttrs)) actualAttrs;
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
    if correctFormat then
      (if invalidAttrs != [ ] then throw topLevelErrorMessage else moduleResult)
    else
      throw formatErrorMessage;

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

        moduleDefaults =
          (import modulePath {
            lib = args.lib;
            pkgs = args.pkgs;
            pkgs-unstable = args.pkgs-unstable;
            funcs = args.funcs;
            helpers = helpers;
            defs = args.defs;
            self = enhancedModuleContext;
          }).defaults or { };

        userSettings = if moduleSettings == true then { } else moduleSettings;
      in
      lib.recursiveUpdate moduleDefaults userSettings;
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
    moduleContext // appliedCommonFuncs // contextFuncs // persistShortcut;

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
        configuration =
          if moduleResult ? configuration then
            moduleResult.configuration
          else if moduleResult ? meta then
            (context: { })
          else
            moduleResult;
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
        configuration =
          if moduleResult ? configuration then
            moduleResult.configuration
          else if moduleResult ? meta then
            (context: { })
          else
            moduleResult;
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
          normalizeSubmodules =
            submodules:
            lib.mapAttrs (
              inputName: inputGroups:
              lib.mapAttrs (
                groupName: groupModules:
                lib.mapAttrs (
                  moduleName: moduleValue: if moduleValue == true then { } else moduleValue
                ) groupModules
              ) inputGroups
            ) submodules;
        in
        normalizeSubmodules rawSubmodules
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
          3
        else if v == true then
          2
        else if v == false then
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

      normalizedInitialModules = normalizeModules initialModules;
      initialModulesWithDefaults = applyDefaultsToModules normalizedInitialModules;

      collectRound =
        processedModules: currentModules: iteration:
        let
          moduleSpecs = processModules currentModules;
          collectedSubmodules = collectSubModules args moduleSpecs moduleType;
          normalizedSubmodules = normalizeModules collectedSubmodules;
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
}
