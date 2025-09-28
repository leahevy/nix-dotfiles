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
        validatedData = args.funcs.validateModule fileData filePath;
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

    # Import file from different module in same input
    # Usage: self.importFileFromOtherModule { inherit args context; group = "shell"; module = "fish"; subpath = "file.nix"; }
    importFileFromOtherModule =
      self:
      {
        args,
        context,
        group,
        module,
        subpath,
      }:
      let
        moduleType = if self ? user then "home" else "system";
        inputPath = helpers.resolveInputFromInput self.moduleInputName;
        filePath = inputPath + "/modules/" + moduleType + "/" + group + "/" + module + "/" + subpath;

        moduleDir = "modules/${moduleType}/${group}/${module}";
        newModuleContext = {
          inputs = self.inputs;
          variables = self.variables;
          configInputs = self.configInputs or { };
          moduleBasePath = moduleDir;
          moduleInput = inputPath;
          moduleInputName = self.moduleInputName;
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

        enhancedContext =
          newModuleContext
          // (lib.mapAttrs (name: func: func newModuleContext) commonFuncs)
          // (
            if moduleType == "home" then
              { user = newModuleContext.user // (lib.mapAttrs (name: func: func newModuleContext) userFuncs); }
            else
              { host = newModuleContext.host // (lib.mapAttrs (name: func: func newModuleContext) hostFuncs); }
          )
          // (
            if moduleType == "home" then
              { persist = "${newModuleContext.variables.persist.home}/${newModuleContext.user.username}"; }
            else
              { persist = newModuleContext.variables.persist.system; }
          );

        importArgs = args // {
          self = enhancedContext;
        };
      in
      (import filePath importArgs) context;

    # Import file from module in another input
    # Usage: self.importFileFromInput { inherit args context; input = "common"; group = "vim"; module = "nixvim"; subpath = "file.nix"; }
    importFileFromInput =
      self:
      {
        args,
        context,
        input,
        group,
        module,
        subpath,
      }:
      let
        moduleType = if self ? user then "home" else "system";
        inputPath = helpers.resolveInputFromInput input;
        filePath = inputPath + "/modules/" + moduleType + "/" + group + "/" + module + "/" + subpath;

        moduleDir = "modules/${moduleType}/${group}/${module}";
        newModuleContext = {
          inputs = self.inputs;
          variables = self.variables;
          configInputs = self.configInputs or { };
          moduleBasePath = moduleDir;
          moduleInput = inputPath;
          moduleInputName = input;
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

        enhancedContext =
          newModuleContext
          // (lib.mapAttrs (name: func: func newModuleContext) commonFuncs)
          // (
            if moduleType == "home" then
              { user = newModuleContext.user // (lib.mapAttrs (name: func: func newModuleContext) userFuncs); }
            else
              { host = newModuleContext.host // (lib.mapAttrs (name: func: func newModuleContext) hostFuncs); }
          )
          // (
            if moduleType == "home" then
              { persist = "${newModuleContext.variables.persist.home}/${newModuleContext.user.username}"; }
            else
              { persist = newModuleContext.variables.persist.system; }
          );

        importArgs = args // {
          self = enhancedContext;
        };
      in
      (import filePath importArgs) context;

  };

  userFuncs = {
  };

  hostFuncs = {
  };

  # Create context-aware function wrapper with error handling
  # Usage: createContextFunctions $INPUTNAME $NAMESPACE $MODULECONTEXT $MODULEBASEPATH
  createContextFunctions =
    inputName: namespace: moduleContext: moduleBasePath:
    let
      currentNamespace = if moduleContext ? user then "home" else "system";
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
      currentNamespace = if moduleContext ? user then "home" else "system";
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
      lib = config: if isStandalone then lib.hm else config.lib;

      # Create custom nixpkgs import with module-scoped unfree predicate
      # Usage: self.pkgs { overlays = [...]; }
      pkgs = createPkgsImport moduleContext.inputs.nixpkgs;

      # Create custom nixpkgs-unstable import with module-scoped unfree predicate
      # Usage: self.pkgs-unstable { overlays = [...]; }
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
          validatedData = args.funcs.validateModule fileData filePath;
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
        // (rec {
          inherit
            lib
            pkgs
            pkgs-unstable
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

    in
    {
      # Check if module is enabled
      isModuleEnabled =
        modulePath:
        if validation.shouldReturnSafeDefaults then
          false
        else
          let
            resolved = resolveModulePath modulePath;
          in
          lib.hasAttrByPath resolved.fullPath modules;

      # Get module config
      getModuleConfig =
        modulePath:
        if validation.shouldReturnSafeDefaults then
          { }
        else
          let
            resolved = resolveModulePath modulePath;
          in
          lib.attrByPath resolved.fullPath { } modules;

      # Require module config
      requireModuleConfig =
        modulePath:
        if validation.shouldReturnSafeDefaults then
          throw "Required module '${inputName}.${modulePath}' is not available in standalone mode"
        else
          let
            resolved = resolveModulePath modulePath;
            config = lib.attrByPath resolved.fullPath { } modules;
          in
          if config != { } then
            config
          else
            throw "Required module '${inputName}.${modulePath}' is not enabled in ${actualNamespace} namespace";
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
      isSameModuleEnabled =
        if validation.shouldReturnSafeDefaults then false else lib.hasAttrByPath fullPath modules;

      # Get same module config from target namespace
      getSameModuleConfig =
        if validation.shouldReturnSafeDefaults then { } else lib.attrByPath fullPath { } modules;

      # Require same module config from target namespace
      requireSameModuleConfig =
        if validation.shouldReturnSafeDefaults then
          throw "Required same module '${inputName}.${moduleName}' is not available in standalone mode"
        else
          let
            config = lib.attrByPath fullPath { } modules;
          in
          if config != { } then
            config
          else
            throw "Required same module '${inputName}.${moduleName}' is not enabled in ${actualNamespace} namespace";
    };
}
