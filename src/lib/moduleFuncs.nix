{
  lib,
  defs,
  additionalInputs,
}:
let
  helpers = import ./helpers.nix {
    inherit lib defs additionalInputs;
  };
in
rec {
  commonFuncs = {

    # Check if current module architecture is Linux
    # Usage: isLinux $SELF
    isLinux =
      self:
      let
        architecture =
          if self ? user && self.user ? architecture then
            self.user.architecture
          else if self ? host && self.host ? architecture then
            self.host.architecture
          else
            throw "No architecture found in self context";
      in
      helpers.isLinuxArch architecture;

    # Check if current module architecture is Darwin/macOS
    # Usage: isDarwin $SELF
    isDarwin =
      self:
      let
        architecture =
          if self ? user && self.user ? architecture then
            self.user.architecture
          else if self ? host && self.host ? architecture then
            self.host.architecture
          else
            throw "No architecture found in self context";
      in
      helpers.isDarwinArch architecture;

    # Check if current module architecture is x86_64
    # Usage: isX86_64 $SELF
    isX86_64 =
      self:
      let
        architecture =
          if self ? user && self.user ? architecture then
            self.user.architecture
          else if self ? host && self.host ? architecture then
            self.host.architecture
          else
            throw "No architecture found in self context";
      in
      helpers.isX86_64Arch architecture;

    # Check if current module architecture is AArch64 (ARM64)
    # Usage: isAARCH64 $SELF
    isAARCH64 =
      self:
      let
        architecture =
          if self ? user && self.user ? architecture then
            self.user.architecture
          else if self ? host && self.host ? architecture then
            self.host.architecture
          else
            throw "No architecture found in self context";
      in
      helpers.isAARCH64Arch architecture;

    # Get absolute path to file in any input's module directory
    # Usage: fileFromInput $SELF $INPUT $SUBPATH
    fileFromInput =
      self: input: subpath:
      helpers.resolveInputFromInput input + "/" + self.moduleBasePath + "/" + subpath;

    # Create symlink to file in any input (local or remote)
    # Usage: symlinkFromInput $SELF $CONFIG $INPUT $SUBPATH
    symlinkFromInput =
      self: config: input: subpath:
      let
        inputPath = helpers.resolveInputFromInput input;
      in
      if helpers.isLocalDevelopmentInput inputPath input then
        helpers.symlinkToHomeDirPath config (
          helpers.getLocalSourcePath input + "/" + self.moduleBasePath + "/" + subpath
        )
      else
        helpers.symlink config (inputPath + "/" + self.moduleBasePath + "/" + subpath);

    # Import nix file data from same module (returns data without applying context)
    # Usage: self.importFileData args "file.nix"
    importFileData =
      self: args: subpath:
      let
        filePath =
          helpers.resolveInputFromInput self.moduleInputName + "/" + self.moduleBasePath + "/" + subpath;
        importArgs = args // {
          self = self;
        };

        fileData = import filePath importArgs;
        validatedData = args.funcs.validateModule fileData filePath {
          inputName = self.moduleInputName;
        };
      in
      validatedData;

    # Import nix custom data from same module (returns data without applying context)
    # Usage: self.importFileCustom args "file.nix"
    importFileCustom =
      self: args: subpath:
      let
        fileData = commonFuncs.importFileData self args subpath;
      in
      fileData.custom or { };

    # Import nix file from same module and apply context to configuration function
    # Usage: self.importFile args context "file.nix"
    importFile =
      self: args: context: subpath:
      let
        filePath =
          helpers.resolveInputFromInput self.moduleInputName + "/" + self.moduleBasePath + "/" + subpath;
        importArgs = args // {
          self = self;
        };
        imported = import filePath importArgs;
      in
      if imported ? configuration then imported.configuration context else { };

    # Import module structure from same input
    # Usage: self.importFileFromOtherModuleSameInput { inherit args; modulePath = "desktop-modules.web-app"; subpath = "file.nix"; }
    importFileFromOtherModuleSameInput =
      self':
      {
        args,
        self,
        modulePath,
        subpath ? null,
      }:
      let
        currentNamespace =
          if self.moduleBasePath != null then
            let
              pathParts = lib.splitString "/" self.moduleBasePath;
              namespaceIndex = lib.findFirst (i: (lib.elemAt pathParts i) == "modules") null (
                lib.range 0 ((lib.length pathParts) - 1)
              );
            in
            if namespaceIndex != null && (namespaceIndex + 1) < lib.length pathParts then
              let
                detected = lib.elemAt pathParts (namespaceIndex + 1);
              in
              if detected == "home" || detected == "system" then
                detected
              else
                throw "Invalid module namespace '${detected}' in path: ${self.moduleBasePath}. Expected 'home' or 'system'"
            else
              throw "Cannot determine module namespace from path: ${self.moduleBasePath}. Expected '.../modules/{home|system}/...'"
          else
            throw "Module basePath is null - cannot determine namespace for importFileFromOtherModuleSameInput";

        moduleType = currentNamespace;
        inputPath = helpers.resolveInputFromInput self.moduleInputName;

        modulePathParts = lib.splitString "." modulePath;
        groupName = lib.head modulePathParts;
        moduleName = lib.last modulePathParts;

        fileName = if subpath == null then "${moduleName}.nix" else subpath;
        filePath =
          inputPath
          + "/modules/"
          + moduleType
          + "/"
          + (lib.concatStringsSep "/" modulePathParts)
          + "/"
          + fileName;

        moduleDir = "modules/${moduleType}/" + (lib.concatStringsSep "/" modulePathParts);
        baseModuleContext = {
          inputs = self.inputs;
          variables = self.variables;
          configInputs = self.configInputs or { };
          moduleBasePath = moduleDir;
          moduleInput = inputPath;
          moduleInputName = self.moduleInputName;
          settings = { };
        }
        // (
          if moduleType == "home" then
            {
              host = self.host;
              user = self.user;
            }
          else
            {
              host = self.host;
              users = self.users;
            }
        );

        enhancedContext = buildHierarchicalFunctions baseModuleContext moduleDir;
        moduleSettings = self.getModuleConfig modulePath;
        finalContext = enhancedContext // {
          settings = moduleSettings;
        };

        importArgs = args // {
          self = finalContext;
        };
      in
      import filePath importArgs;

    # Import module structure from different input
    # Usage: self.importFileFromOtherModuleOtherInput { inherit args; inputName = "common"; modulePath = "shell.fish"; subpath = "file.nix"; }
    importFileFromOtherModuleOtherInput =
      self':
      {
        args,
        self,
        inputName,
        modulePath,
        subpath ? null,
      }:
      let
        currentNamespace =
          if self.moduleBasePath != null then
            let
              pathParts = lib.splitString "/" self.moduleBasePath;
              namespaceIndex = lib.findFirst (i: (lib.elemAt pathParts i) == "modules") null (
                lib.range 0 ((lib.length pathParts) - 1)
              );
            in
            if namespaceIndex != null && (namespaceIndex + 1) < lib.length pathParts then
              let
                detected = lib.elemAt pathParts (namespaceIndex + 1);
              in
              if detected == "home" || detected == "system" then
                detected
              else
                throw "Invalid module namespace '${detected}' in path: ${self.moduleBasePath}. Expected 'home' or 'system'"
            else
              throw "Cannot determine module namespace from path: ${self.moduleBasePath}. Expected '.../modules/{home|system}/...'"
          else
            throw "Module basePath is null - cannot determine namespace for importFileFromOtherModuleOtherInput";

        moduleType = currentNamespace;
        inputPath = helpers.resolveInputFromInput inputName;

        modulePathParts = lib.splitString "." modulePath;
        groupName = lib.head modulePathParts;
        moduleName = lib.last modulePathParts;

        fileName = if subpath == null then "${moduleName}.nix" else subpath;
        filePath =
          inputPath
          + "/modules/"
          + moduleType
          + "/"
          + (lib.concatStringsSep "/" modulePathParts)
          + "/"
          + fileName;

        moduleDir = "modules/${moduleType}/" + (lib.concatStringsSep "/" modulePathParts);
        baseModuleContext = {
          inputs = self.inputs;
          variables = self.variables;
          configInputs = self.configInputs or { };
          moduleBasePath = moduleDir;
          moduleInput = inputPath;
          moduleInputName = inputName;
          settings = { };
        }
        // (
          if moduleType == "home" then
            {
              host = self.host;
              user = self.user;
            }
          else
            {
              host = self.host;
              users = self.users;
            }
        );

        enhancedContext = buildHierarchicalFunctions baseModuleContext moduleDir;
        moduleSettings = self.${inputName}.getModuleConfig modulePath;
        finalContext = enhancedContext // {
          settings = moduleSettings;
        };

        importArgs = args // {
          self = finalContext;
        };
      in
      import filePath importArgs;

  };

  userFuncs = { };

  hostFuncs = { };

  # Create context-aware function wrapper with error handling
  # Usage: createContextFunctions $INPUTNAME $NAMESPACE $MODULECONTEXT $MODULEBASEPATH
  createContextFunctions =
    inputName: namespace: moduleContext: moduleBasePath:
    let
      currentNamespace = namespace;
      isStandalone = moduleContext.user.isStandalone or false;

      fileFunctions = generateFileFunctions inputName moduleBasePath;
      moduleFunctions = generateModuleFunctions inputName namespace moduleContext;
      sameModuleFunctions = generateSameModuleFunctions inputName namespace moduleContext moduleBasePath;

    in
    fileFunctions // moduleFunctions // sameModuleFunctions;

  # Build complete hierarchical function system
  # Usage: buildHierarchicalFunctions $MODULECONTEXT $MODULEBASEPATH
  buildHierarchicalFunctions =
    moduleContext: moduleBasePath:
    let
      currentNamespace =
        if moduleBasePath != null then
          let
            pathParts = lib.splitString "/" moduleBasePath;
            namespaceIndex = lib.findFirst (i: (lib.elemAt pathParts i) == "modules") null (
              lib.range 0 ((lib.length pathParts) - 1)
            );
          in
          if namespaceIndex != null && (namespaceIndex + 1) < lib.length pathParts then
            let
              detected = lib.elemAt pathParts (namespaceIndex + 1);
            in
            if detected == "home" || detected == "system" then
              detected
            else
              throw "Invalid module namespace '${detected}' in path: ${moduleBasePath}. Expected 'home' or 'system'"
          else
            throw "Cannot determine module namespace from path: ${moduleBasePath}. Expected '.../modules/{home|system}/...'"
        else
          throw "Module basePath is null - cannot determine namespace";

      currentInputName = moduleContext.moduleInputName;
      isStandalone = moduleContext.user.isStandalone or false;

      contextDefaults =
        createContextFunctions currentInputName currentNamespace moduleContext
          moduleBasePath;

      hostFunctions = createContextFunctions currentInputName "host" moduleContext moduleBasePath;
      userFunctions = createContextFunctions currentInputName "user" moduleContext moduleBasePath;

      inputSpecificFunctions = lib.mapAttrs (
        inputName: _: createContextFunctions inputName currentNamespace moduleContext moduleBasePath
      ) additionalInputs;

      inputNamespaceFunctions = lib.mapAttrs (
        inputName: _:
        let
          inputSpecificFuncs = inputSpecificFunctions.${inputName} or { };
          namespaceFuncs = {
            host = createContextFunctions inputName "host" moduleContext moduleBasePath;
            user = createContextFunctions inputName "user" moduleContext moduleBasePath;
          };
        in
        inputSpecificFuncs // namespaceFuncs
      ) additionalInputs;

    in
    let
      # Create custom nixpkgs imports with module-scoped unfree predicate
      createPkgsImport =
        nixpkgsInput: additionalArgs:
        let
          moduleUnfree = moduleContext.unfree or [ ];
          allowUnfreePredicate =
            pkg:
            let
              pkgName = pkg.pname or pkg.name or "unknown";
            in
            builtins.elem pkgName moduleUnfree;

          architecture =
            if moduleContext ? user && moduleContext.user ? architecture then
              moduleContext.user.architecture
            else if moduleContext ? host && moduleContext.host ? architecture then
              moduleContext.host.architecture
            else
              throw "No architecture found in self context for pkgs import";
        in
        import nixpkgsInput (
          {
            system = architecture;
            config = { inherit allowUnfreePredicate; };
          }
          // additionalArgs
        );
    in
    rec {
      # Get Home Manager library functions - always takes config parameter
      # Usage: self.lib $CONFIG
      hmLib = config: config.lib;

      # Create custom nixpkgs import with module-scoped unfree predicate
      # Usage: self . pkgs { overlays = [...]; }
      pkgs = createPkgsImport moduleContext.inputs.nixpkgs;

      # Create a dummy package usable for creating home-manager config without installing the package
      # Usage: self.dummyPackage $NAME
      dummyPackage =
        name:
        (pkgs { }).runCommand name
          {
            meta.mainProgram = name;
          }
          ''
            mkdir -p $out/bin
            touch $out/bin/${name}
            chmod +x $out/bin/${name}
          '';

      # Create custom nixpkgs-unstable import with module-scoped unfree predicate
      # Usage: self . pkgs-unstable { overlays = [...]; }
      pkgs-unstable = createPkgsImport moduleContext.inputs.nixpkgs-unstable;

      host = (moduleContext.host or { }) // hostFunctions;
      user = (moduleContext.user or { }) // userFunctions;

      importFileData =
        args: subpath:
        let
          filePath =
            helpers.resolveInputFromInput moduleContext.moduleInputName
            + "/"
            + moduleContext.moduleBasePath
            + "/"
            + subpath;
          importArgs = args // {
            self = finalContext;
          };
          fileData = import filePath importArgs;
          validatedData = args.funcs.validateModule fileData filePath {
            inputName = moduleContext.moduleInputName;
          };
        in
        validatedData;

      importFileCustom =
        args: subpath:
        let
          fileData = importFileData args subpath;
        in
        fileData.custom or { };

      finalContext =
        contextDefaults
        // (lib.mapAttrs (
          _name: func: if builtins.isFunction func then func finalContext else func
        ) commonFuncs)
        // (rec {
          inherit
            hmLib
            pkgs
            pkgs-unstable
            dummyPackage
            host
            user
            importFileData
            importFileCustom
            ;
        })
        // inputNamespaceFunctions
        // {
          inherit (moduleContext)
            settings
            moduleBasePath
            moduleInputName
            moduleInput
            inputs
            variables
            configInputs
            ;
        };
    }
    .finalContext;

  # Generate complete hierarchical input function system
  # Usage: hierarchicalInputFuncs $MODULECONTEXT $MODULEBASEPATH
  hierarchicalInputFuncs =
    moduleContext: moduleBasePath: buildHierarchicalFunctions moduleContext moduleBasePath;

  # Validate module context access patterns
  # Usage: validateContext $MODULECONTEXT $TARGETNAMESPACE
  validateContext =
    moduleContext: targetNamespace:
    let
      currentNamespace = if moduleContext ? user then "home" else "system";
      isStandalone = moduleContext.user.isStandalone or false;
    in
    {
      canAccessNamespace = true;
      shouldReturnSafeDefaults = isStandalone;

      resolveActualNamespace =
        if isStandalone then
          "standalone"
        else if targetNamespace == "host" && currentNamespace == "system" then
          "system"
        else if targetNamespace == "user" && currentNamespace == "home" then
          "home"
        else if targetNamespace == "host" then
          "system"
        else if targetNamespace == "user" then
          "home"
        else if targetNamespace == "system" then
          "system"
        else if targetNamespace == "home" then
          "home"
        else
          currentNamespace;
    };

  # Generate file access functions for specific input and module path
  # Usage: generateFileFunctions $INPUTNAME $MODULEBASEPATH
  generateFileFunctions = inputName: moduleBasePath: {
    file =
      subPath:
      let
        relativePath =
          if moduleBasePath != null then "${moduleBasePath}/files/${subPath}" else "files/${subPath}";
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} relativePath;
      in
      if builtins.pathExists fullPath then
        fullPath
      else
        throw "File not found: ${inputName}/${relativePath}";

    # Get absolute path to secret file in input (module-relative when moduleBasePath provided)
    secret =
      subPath:
      let
        relativePath =
          if moduleBasePath != null then "${moduleBasePath}/secrets/${subPath}" else "secrets/${subPath}";
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} relativePath;
      in
      if builtins.pathExists fullPath then
        fullPath
      else
        throw "Secret file not found: ${inputName}/${relativePath}";

    # Get absolute path to file in input root files/ directory
    filesPath =
      subPath:
      let
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} ("files/" + subPath);
      in
      if builtins.pathExists fullPath then
        fullPath
      else
        throw "Root file not found: ${inputName}/files/${subPath}";

    # Get absolute path to secret in input root secrets/ directory
    secretsPath =
      subPath:
      let
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} ("secrets/" + subPath);
      in
      if builtins.pathExists fullPath then
        fullPath
      else
        throw "Root secret not found: ${inputName}/secrets/${subPath}";

    # Get relative path to file in input
    fileRel =
      subPath:
      let
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} ("files/" + subPath);
      in
      if builtins.pathExists fullPath then
        helpers.getInputFilePathRel inputName ("files/" + subPath)
      else
        throw "File not found: ${inputName}/files/${subPath}";

    # Get relative path to secret file in input
    secretRel =
      subPath:
      let
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} ("secrets/" + subPath);
      in
      if builtins.pathExists fullPath then
        helpers.getInputFilePathRel inputName ("secrets/" + subPath)
      else
        throw "Secret file not found: ${inputName}/secrets/${subPath}";

    # Create symlink to file in input (module-relative when moduleBasePath provided)
    symlinkFile =
      config: subPath:
      let
        relativePath =
          if moduleBasePath != null then "${moduleBasePath}/files/${subPath}" else "files/${subPath}";
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} relativePath;
      in
      if builtins.pathExists fullPath then
        if helpers.isLocalDevelopmentInput null inputName then
          helpers.symlinkToHomeDirPath config (helpers.getLocalSourcePath inputName + "/" + relativePath)
        else
          helpers.symlink config (additionalInputs.${inputName} + "/" + relativePath)
      else
        throw "File not found: ${inputName}/${relativePath}";

    # Create symlink to secret file in input (module-relative when moduleBasePath provided)
    symlinkSecret =
      config: subPath:
      let
        relativePath =
          if moduleBasePath != null then "${moduleBasePath}/secrets/${subPath}" else "secrets/${subPath}";
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} relativePath;
      in
      if builtins.pathExists fullPath then
        if helpers.isLocalDevelopmentInput null inputName then
          helpers.symlinkToHomeDirPath config (helpers.getLocalSourcePath inputName + "/" + relativePath)
        else
          helpers.symlink config (additionalInputs.${inputName} + "/" + relativePath)
      else
        throw "Secret file not found: ${inputName}/${relativePath}";
  };

  # Generate module query functions for specific input and namespace
  # Usage: generateModuleFunctions $INPUTNAME $REQUESTEDNAMESPACE $MODULECONTEXT
  generateModuleFunctions =
    inputName: requestedNamespace: moduleContext:
    let
      validation = validateContext moduleContext requestedNamespace;
      actualNamespace = validation.resolveActualNamespace;

      getModulesForNamespace =
        ns:
        if ns == "standalone" then
          if moduleContext ? user && moduleContext.user != null then
            moduleContext.user.processedModules or moduleContext.user.modules or { }
          else
            { }
        else if ns == "home" then
          if moduleContext ? user && moduleContext.user != null then
            moduleContext.user.processedModules or moduleContext.user.modules or { }
          else if moduleContext ? host && moduleContext.host ? mainUser then
            moduleContext.host.mainUser.processedModules or moduleContext.host.mainUser.modules or { }
          else
            { }
        else if ns == "system" then
          if moduleContext ? host then
            moduleContext.host.processedModules or moduleContext.host.modules or { }
          else
            { }
        else
          throw "Invalid namespace: ${ns}";

      modules = getModulesForNamespace actualNamespace;

      resolveModulePath =
        modulePath:
        let
          pathParts = lib.splitString "." modulePath;
          fullPath = [ inputName ] ++ pathParts;
        in
        {
          inherit fullPath pathParts;
        };

      # Check if module is enabled
      isModuleEnabled =
        modulePath:
        let
          resolved = resolveModulePath modulePath;
          completeModules =
            if actualNamespace == "system" && moduleContext ? host && moduleContext.host ? processedModules then
              moduleContext.host.processedModules
            else
              getModulesForNamespace actualNamespace;
        in
        lib.hasAttrByPath resolved.fullPath completeModules;

      # Get module config
      getModuleConfig =
        modulePath:
        let
          resolved = resolveModulePath modulePath;
          completeModules =
            if actualNamespace == "system" && moduleContext ? host && moduleContext.host ? processedModules then
              moduleContext.host.processedModules
            else
              getModulesForNamespace actualNamespace;
        in
        lib.attrByPath resolved.fullPath { } completeModules;

      # Require module config
      requireModuleConfig =
        modulePath:
        let
          resolved = resolveModulePath modulePath;
          completeModules =
            if actualNamespace == "system" && moduleContext ? host && moduleContext.host ? processedModules then
              moduleContext.host.processedModules
            else
              getModulesForNamespace actualNamespace;
          config = lib.attrByPath resolved.fullPath { } completeModules;
        in
        if config != { } then
          config
        else
          throw "Required module '${inputName}.${modulePath}' is not enabled in ${actualNamespace} namespace";

      availableThemes =
        let
          themesDir = moduleContext.inputs.themes + "/modules/home/themes";
        in
        builtins.filter (name: name != "base") (builtins.attrNames (builtins.readDir themesDir));

      theme =
        let
          activeTheme =
            if moduleContext.host or null != null && moduleContext.host.settings.theme or null != null then
              moduleContext.host.settings.theme
            else if moduleContext.user or null != null && moduleContext.user.settings.theme or null != null then
              moduleContext.user.settings.theme
            else
              moduleContext.variables.defaultTheme;

          themesDir = moduleContext.inputs.themes + "/modules/home/themes";
          existingThemes = builtins.attrNames (builtins.readDir themesDir);

          themeModulePath =
            moduleContext.inputs.themes + "/modules/home/themes/${activeTheme}/${activeTheme}.nix";

          themeModule =
            if builtins.pathExists themeModulePath then
              import themeModulePath {
                inherit lib;
                pkgs = null;
                pkgs-unstable = null;
                funcs = null;
                helpers = null;
                defs = null;
                self = null;
              }
            else
              throw "Theme '${activeTheme}' not found at ${themeModulePath}. Available themes: ${builtins.concatStringsSep ", " existingThemes}";
        in
        themeModule.settings;
    in
    {
      inherit
        isModuleEnabled
        getModuleConfig
        requireModuleConfig
        theme
        availableThemes
        ;
    };

  # Generate same module query functions for specific input, namespace and module path
  # Usage: generateSameModuleFunctions $INPUTNAME $REQUESTEDNAMESPACE $MODULECONTEXT $MODULEBASEPATH
  generateSameModuleFunctions =
    inputName: requestedNamespace: moduleContext: moduleBasePath:
    let
      validation = validateContext moduleContext requestedNamespace;
      actualNamespace = validation.resolveActualNamespace;

      getModuleNameFromPath =
        basePath:
        let
          parts = lib.splitString "/" basePath;
          moduleParts = lib.drop 2 parts;
        in
        lib.concatStringsSep "." moduleParts;

      moduleName = getModuleNameFromPath moduleBasePath;

      getModulesForNamespace =
        ns:
        if ns == "standalone" then
          if moduleContext ? user then
            moduleContext.user.processedModules or moduleContext.user.modules or { }
          else
            { }
        else if ns == "home" then
          if moduleContext ? user then
            moduleContext.user.processedModules or moduleContext.user.modules or { }
          else if moduleContext ? host && moduleContext.host ? mainUser then
            moduleContext.host.mainUser.modules or { }
          else
            { }
        else if ns == "system" then
          if moduleContext ? host then
            moduleContext.host.processedModules or moduleContext.host.modules or { }
          else
            { }
        else
          throw "Invalid namespace: ${ns}";

      modules = getModulesForNamespace actualNamespace;
      pathParts = lib.splitString "." moduleName;
      fullPath = [ inputName ] ++ pathParts;

    in
    {
      # Check if same module is enabled in target namespace
      isSameModuleEnabled = lib.hasAttrByPath fullPath modules;

      # Get same module config from target namespace
      getSameModuleConfig = lib.attrByPath fullPath { } modules;

      # Require same module config from target namespace
      requireSameModuleConfig =
        let
          config = lib.attrByPath fullPath { } modules;
        in
        if config != { } then
          config
        else
          throw "Required same module '${inputName}.${moduleName}' is not enabled in ${actualNamespace} namespace";
    };
}
