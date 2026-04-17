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

    # Create symlink to file in any input (local or remote); not allowed in core inputs
    # Usage: symlinkFromInput $SELF $CONFIG $INPUT $SUBPATH
    symlinkFromInput =
      self: config: input: subpath:
      if builtins.elem self.moduleInputName defs.coreInputs then
        throw "Symlinks are not allowed in core input '${self.moduleInputName}' (module: ${self.moduleBasePath})."
      else
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
          helpers.resolveInputFromInput self.moduleInputName
          + "/"
          + self.moduleBasePath
          + ".nix.d/"
          + subpath;
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

    # Import nix file from same module and return its module.* functions
    # Usage: self.importFile args "file.nix"
    importFile =
      self: args: subpath:
      let
        filePath =
          helpers.resolveInputFromInput self.moduleInputName
          + "/"
          + self.moduleBasePath
          + ".nix.d/"
          + subpath;
        importArgs = args // {
          self = self;
        };
        imported = import filePath importArgs;
      in
      if imported ? module then imported.module else { };

    # Send a user notification, preferring nx-user-notify (logger) when enabled, else raw notify-send (osascript -e 'display notification...' on Darwin)
    # Usage: self.notifyUser { title = "..."; body = "..."; icon = "dialog-information"; urgency = "normal"; }
    # urgency: "low" | "normal" | "critical"
    # validation: optional { config } — if given, validates the icon name exists in the icon cache; skipped for absolute paths
    # autoFormat: default true — detects $VAR / ${VAR} in body and uses jq at runtime for safe JSON encoding; set false to disable
    notifyUser =
      self:
      {
        pkgs,
        title,
        body,
        icon ? "dialog-information",
        urgency ? "normal",
        validation ? null,
        autoFormat ? true,
      }@args:
      let
        validUrgencies = [
          "low"
          "normal"
          "critical"
        ];
        pkgs = if args.pkgs != "" then args.pkgs else throw "notifyUser: pkgs argument is required";
        title =
          if builtins.isString args.title && args.title != "" then
            args.title
          else
            throw "notifyUser: title must be a non-empty string";
        body =
          if builtins.isString args.body && args.body != "" then
            args.body
          else
            throw "notifyUser: body must be a non-empty string";
        urgency =
          let
            v = args.urgency or "normal";
          in
          if builtins.elem v validUrgencies then
            v
          else
            throw "notifyUser: urgency must be one of ${lib.concatStringsSep ", " validUrgencies}, got '${v}'";
        validation =
          let
            v = args.validation or null;
          in
          if v == null then
            null
          else if !(v ? config) then
            throw "notifyUser: validation requires 'config' field"
          else
            v;
        icon =
          let
            v = args.icon or "dialog-information";
            isValid = (builtins.isString v && v != "") || (builtins.isList v && v != [ ]);
            iconStr = if builtins.isString v then v else lib.concatStringsSep "|" v;
          in
          if !isValid then
            throw "notifyUser: icon must be a non-empty string or list of strings"
          else if validation != null && !self.isDarwin && !(lib.hasPrefix "/" iconStr) then
            helpers.icons.searchIcon validation.config iconStr
          else
            iconStr;
        autoFormat =
          let
            v = args.autoFormat or true;
          in
          if !builtins.isBool v then throw "notifyUser: autoFormat must be a boolean" else v;
        isDynamic = autoFormat && builtins.match ''.*\$[{]?[A-Za-z_][A-Za-z0-9_]*[}]?.*'' body != null;
        loggerPriority =
          if urgency == "critical" then
            "user.err"
          else if urgency == "low" then
            "user.info"
          else
            "user.notice";
        jsonPayload = builtins.toJSON { inherit title body icon; };
        userNotifyEnabled = self.linux.isModuleEnabled "notifications.user-notify";
        shellTitle = lib.escapeShellArg title;
        shellIcon = lib.escapeShellArg icon;
        shellUrgency = lib.escapeShellArg urgency;
        shellBody = lib.replaceStrings [ "\"" ] [ "\\\"" ] body;
        commentBody = lib.replaceStrings [ "\n" ] [ " " ] body;
        scriptContent =
          if self.isDarwin then
            if isDynamic then
              ''
                # ${commentBody}
                export _NOTIFY_TITLE=${shellTitle}
                export _NOTIFY_BODY="$1"
                /usr/bin/osascript -e 'display notification (system attribute "_NOTIFY_BODY") with title (system attribute "_NOTIFY_TITLE")'
              ''
            else
              ''
                export _NOTIFY_TITLE=${shellTitle}
                export _NOTIFY_BODY=${lib.escapeShellArg body}
                /usr/bin/osascript -e 'display notification (system attribute "_NOTIFY_BODY") with title (system attribute "_NOTIFY_TITLE")'
              ''
          else if userNotifyEnabled then
            if isDynamic then
              ''
                # ${commentBody}
                export _NOTIFY_TITLE=${shellTitle}
                export _NOTIFY_ICON=${shellIcon}
                export _NOTIFY_BODY="$1"
                ${pkgs.util-linux}/bin/logger -p ${loggerPriority} -t nx-user-notify "JSON-DATA::$(${pkgs.jq}/bin/jq -cn '{title:$ENV._NOTIFY_TITLE,body:$ENV._NOTIFY_BODY,icon:$ENV._NOTIFY_ICON}')"
              ''
            else
              ''
                ${pkgs.util-linux}/bin/logger -p ${loggerPriority} -t nx-user-notify ${lib.escapeShellArg "JSON-DATA::${jsonPayload}"}
              ''
          else if isDynamic then
            ''
              # ${commentBody}
              ${pkgs.libnotify}/bin/notify-send --urgency=${shellUrgency} --icon=${shellIcon} ${shellTitle} "$1"
            ''
          else
            ''
              ${pkgs.libnotify}/bin/notify-send --urgency=${shellUrgency} --icon=${shellIcon} ${shellTitle} ${lib.escapeShellArg body}
            '';
        script = pkgs.writeShellScript "nx-notify" scriptContent;
      in
      if isDynamic then "${script} \"${shellBody}\"" else "${script}";

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
        inputPath = helpers.resolveInputFromInput self.moduleInputName;

        modulePathParts = lib.splitString "." modulePath;
        groupName = lib.head modulePathParts;
        moduleName = lib.last modulePathParts;

        filePath =
          if subpath == null then
            helpers.buildModuleFilePath inputPath self.moduleInputName groupName moduleName
          else
            helpers.buildModuleFilePath inputPath self.moduleInputName groupName moduleName + ".d/${subpath}";

        moduleDir = helpers.buildModuleDir self.moduleInputName groupName moduleName;
        baseModuleContext = {
          inputs = self.inputs;
          variables = self.variables;
          configInputs = self.configInputs or { };
          moduleBasePath = moduleDir;
          moduleInput = inputPath;
          moduleInputName = self.moduleInputName;
          settings = { };
          host = self.host or { };
          user = self.user or null;
          users = self.users or { };
          processedModules = self.processedModules or { };
        };

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
        inputPath = helpers.resolveInputFromInput inputName;

        modulePathParts = lib.splitString "." modulePath;
        groupName = lib.head modulePathParts;
        moduleName = lib.last modulePathParts;

        filePath =
          if subpath == null then
            helpers.buildModuleFilePath inputPath inputName groupName moduleName
          else
            helpers.buildModuleFilePath inputPath inputName groupName moduleName + ".d/${subpath}";

        moduleDir = helpers.buildModuleDir inputName groupName moduleName;
        baseModuleContext = {
          inputs = self.inputs;
          variables = self.variables;
          configInputs = self.configInputs or { };
          moduleBasePath = moduleDir;
          moduleInput = inputPath;
          moduleInputName = inputName;
          settings = { };
          host = self.host or { };
          user = self.user or null;
          users = self.users or { };
          processedModules = self.processedModules or { };
        };

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

  # Create context-aware function wrapper with error handling
  # Usage: createContextFunctions $INPUTNAME $MODULECONTEXT $MODULEBASEPATH
  createContextFunctions =
    inputName: moduleContext: moduleBasePath:
    let
      fileFunctions = generateFileFunctions inputName moduleBasePath;
      moduleFunctions = generateModuleFunctions inputName moduleContext;
      sameModuleFunctions = generateSameModuleFunctions inputName moduleContext moduleBasePath;
    in
    fileFunctions // moduleFunctions // sameModuleFunctions;

  # Build complete hierarchical function system
  # Usage: buildHierarchicalFunctions $MODULECONTEXT $MODULEBASEPATH
  buildHierarchicalFunctions =
    moduleContext: moduleBasePath:
    let
      currentInputName = moduleContext.moduleInputName;

      pathParts = lib.splitString "/" moduleBasePath;
      moduleGroupName =
        if builtins.length pathParts >= 3 then
          builtins.elemAt pathParts 1
        else if builtins.length pathParts >= 2 then
          builtins.elemAt pathParts 0
        else
          null;
      moduleModuleName =
        if builtins.length pathParts >= 3 then
          builtins.elemAt pathParts 2
        else if builtins.length pathParts >= 2 then
          builtins.elemAt pathParts 1
        else
          null;

      contextDefaults = createContextFunctions currentInputName moduleContext moduleBasePath;

      inputSpecificFunctions = lib.mapAttrs (
        inputName: _: createContextFunctions inputName moduleContext moduleBasePath
      ) additionalInputs;

    in
    rec {
      # Get Home Manager library functions - always takes config parameter
      # Usage: self.lib $CONFIG
      hmLib = config: config.lib;

      # Create a dummy package usable for creating home-manager config without installing the package
      # Usage: self.dummyPackage pkgs $NAME
      dummyPackage =
        pkgs: name:
        pkgs.runCommand name
          {
            meta.mainProgram = name;
          }
          ''
            mkdir -p $out/bin
            touch $out/bin/${name}
            chmod +x $out/bin/${name}
          '';

      host = if moduleContext ? host && moduleContext.host != null then moduleContext.host else { };
      user = if moduleContext ? user && moduleContext.user != null then moduleContext.user else { };

      importFileData =
        args: subpath:
        let
          filePath =
            helpers.resolveInputFromInput moduleContext.moduleInputName
            + "/"
            + moduleContext.moduleBasePath
            + ".nix.d/"
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
        // {
          inherit
            hmLib
            dummyPackage
            host
            user
            importFileData
            importFileCustom
            ;
        }
        // inputSpecificFunctions
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

          options =
            config:
            if moduleGroupName != null && moduleModuleName != null then
              config.nx.${currentInputName}.${moduleGroupName}.${moduleModuleName} or { }
            else
              { };

          isEnabled =
            let
              processedModules = moduleContext.processedModules or { };
            in
            moduleGroupName != null
            && moduleModuleName != null
            && lib.hasAttrByPath [ currentInputName moduleGroupName moduleModuleName ] processedModules;
        };
    }
    .finalContext;

  # Generate complete hierarchical input function system
  # Usage: hierarchicalInputFuncs $MODULECONTEXT $MODULEBASEPATH
  hierarchicalInputFuncs =
    moduleContext: moduleBasePath: buildHierarchicalFunctions moduleContext moduleBasePath;

  # Generate file access functions for specific input and module path
  # Usage: generateFileFunctions $INPUTNAME $MODULEBASEPATH
  generateFileFunctions = inputName: moduleBasePath: {
    rootPath = subPath: additionalInputs.${inputName} + "/" + subPath;

    file =
      subPath:
      let
        relativePath =
          if moduleBasePath != null then "${moduleBasePath}.nix.d/${subPath}" else "files/${subPath}";
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} relativePath;
      in
      if builtins.pathExists fullPath then
        if lib.hasSuffix ".nix" subPath then
          fullPath
        else
          builtins.path {
            path = fullPath;
            name = builtins.baseNameOf subPath;
          }
      else
        throw "File not found: ${inputName}/${relativePath}";

    secret =
      subPath:
      let
        relativePath =
          if moduleBasePath != null then
            "${moduleBasePath}.nix.d/secrets/${subPath}"
          else
            "secrets/${subPath}";
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} relativePath;
      in
      if builtins.pathExists fullPath then
        if lib.hasSuffix ".nix" subPath then
          fullPath
        else
          builtins.path {
            path = fullPath;
            name = builtins.baseNameOf subPath;
          }
      else
        throw "Secret file not found: ${inputName}/${relativePath}";

    filesPath =
      subPath:
      let
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} ("files/" + subPath);
      in
      if builtins.pathExists fullPath then
        if lib.hasSuffix ".nix" subPath then
          fullPath
        else
          builtins.path {
            path = fullPath;
            name = builtins.baseNameOf subPath;
          }
      else
        throw "Root file not found: ${inputName}/files/${subPath}";

    secretsPath =
      subPath:
      let
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} ("secrets/" + subPath);
      in
      if builtins.pathExists fullPath then
        if lib.hasSuffix ".nix" subPath then
          fullPath
        else
          builtins.path {
            path = fullPath;
            name = builtins.baseNameOf subPath;
          }
      else
        throw "Root secret not found: ${inputName}/secrets/${subPath}";

    fileRel =
      subPath:
      let
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} ("files/" + subPath);
      in
      if builtins.pathExists fullPath then
        helpers.getInputFilePathRel inputName ("files/" + subPath)
      else
        throw "File not found: ${inputName}/files/${subPath}";

    secretRel =
      subPath:
      let
        fullPath = helpers.getInputFilePath additionalInputs.${inputName} ("secrets/" + subPath);
      in
      if builtins.pathExists fullPath then
        helpers.getInputFilePathRel inputName ("secrets/" + subPath)
      else
        throw "Secret file not found: ${inputName}/secrets/${subPath}";

    # Create symlink to file in this module's input; not allowed in core inputs
    symlinkFile =
      config: subPath:
      if builtins.elem inputName defs.coreInputs then
        throw "Symlinks are not allowed in core input '${inputName}' (module: ${moduleBasePath})."
      else
        let
          relativePath =
            if moduleBasePath != null then "${moduleBasePath}.nix.d/${subPath}" else "files/${subPath}";
          fullPath = helpers.getInputFilePath additionalInputs.${inputName} relativePath;
        in
        if builtins.pathExists fullPath then
          if helpers.isLocalDevelopmentInput null inputName then
            helpers.symlinkToHomeDirPath config (helpers.getLocalSourcePath inputName + "/" + relativePath)
          else
            helpers.symlink config (additionalInputs.${inputName} + "/" + relativePath)
        else
          throw "File not found: ${inputName}/${relativePath}";

    # Create symlink to secret file in this module's input; not allowed in core inputs
    symlinkSecret =
      config: subPath:
      if builtins.elem inputName defs.coreInputs then
        throw "Symlinks are not allowed in core input '${inputName}' (module: ${moduleBasePath})."
      else
        let
          relativePath =
            if moduleBasePath != null then
              "${moduleBasePath}.nix.d/secrets/${subPath}"
            else
              "secrets/${subPath}";
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
    inputName: moduleContext:
    let
      processedModules = moduleContext.processedModules or { };

      resolveModulePath =
        modulePath:
        let
          pathParts = lib.splitString "." modulePath;
          fullPath = [ inputName ] ++ pathParts;
        in
        {
          inherit fullPath pathParts;
        };

      isModuleEnabled =
        modulePath:
        let
          resolved = resolveModulePath modulePath;
        in
        lib.hasAttrByPath resolved.fullPath processedModules;

      getModuleConfig =
        modulePath:
        let
          resolved = resolveModulePath modulePath;
        in
        lib.attrByPath resolved.fullPath { } processedModules;

      requireModuleConfig =
        modulePath:
        let
          resolved = resolveModulePath modulePath;
          config = lib.attrByPath resolved.fullPath { } processedModules;
        in
        if config != { } then
          config
        else
          throw "Required module '${inputName}.${modulePath}' is not enabled";

      availableThemes =
        let
          themesDir = moduleContext.inputs.themes + "/themes";
        in
        if builtins.pathExists themesDir then
          builtins.filter (name: name != "base") (
            map (lib.removeSuffix ".nix") (
              builtins.filter (lib.hasSuffix ".nix") (builtins.attrNames (builtins.readDir themesDir))
            )
          )
        else
          [ ];
    in
    {
      inherit
        isModuleEnabled
        getModuleConfig
        requireModuleConfig
        availableThemes
        ;
    };

  # Generate same module query functions for specific input, namespace and module path
  # Usage: generateSameModuleFunctions $INPUTNAME $REQUESTEDNAMESPACE $MODULECONTEXT $MODULEBASEPATH
  generateSameModuleFunctions =
    inputName: moduleContext: moduleBasePath:
    let
      processedModules = moduleContext.processedModules or { };

      getModuleNameFromPath =
        basePath:
        let
          parts = lib.splitString "/" basePath;
          moduleParts = lib.drop 1 parts;
        in
        lib.concatStringsSep "." moduleParts;

      moduleName = getModuleNameFromPath moduleBasePath;
      pathParts = lib.splitString "." moduleName;
      fullPath = [ inputName ] ++ pathParts;
    in
    {
      isSameModuleEnabled = lib.hasAttrByPath fullPath processedModules;

      getSameModuleConfig = lib.attrByPath fullPath { } processedModules;

      requireSameModuleConfig =
        let
          config = lib.attrByPath fullPath { } processedModules;
        in
        if config != { } then
          config
        else
          throw "Required same module '${inputName}.${moduleName}' is not enabled";
    };
}
