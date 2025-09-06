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
        config.lib.file.mkOutOfStoreSymlink (inputPath + "/" + self.moduleBasePath + "/" + subpath);

    # Get absolute path to file in module's own input directory
    # Usage: file $SELF $SUBPATH
    file =
      self: subpath:
      helpers.resolveInputFromInput self.moduleInputName + "/" + self.moduleBasePath + "/" + subpath;

    # Get absolute path to secrets file in config input only
    # Usage: secretsFile $SELF $SUBPATH
    secretsFile = self: subpath: additionalInputs.config + "/" + self.moduleBasePath + "/" + subpath;

    # Create symlink to file in module's own input
    # Usage: symlinkFile $SELF $CONFIG $SUBPATH
    symlinkFile =
      self: config: subpath:
      let
        inputPath = helpers.resolveInputFromInput self.moduleInputName;
      in
      if helpers.isLocalDevelopmentInput inputPath self.moduleInputName then
        helpers.symlinkToHomeDirPath config (
          helpers.getLocalSourcePath self.moduleInputName + "/" + self.moduleBasePath + "/" + subpath
        )
      else
        config.lib.file.mkOutOfStoreSymlink (inputPath + "/" + self.moduleBasePath + "/" + subpath);

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
    # Get absolute path to user profile secrets file
    # Usage: secrets $SELF $SUBPATH
    secrets =
      self: subpath:
      let
        user = self.user;
        profileType = helpers.profileTypeForUser user;
        configInput = additionalInputs.config;
        fullPath =
          configInput + "/profiles" + ("/" + profileType + "/" + user.profileName + "/secrets/" + subpath);
      in
      if builtins.pathExists fullPath then
        fullPath
      else
        throw "Secret file not found: config/profiles/${profileType}/${user.profileName}/secrets/${subpath}";

    # Get absolute path to user profile files
    # Usage: files $SELF $SUBPATH
    files =
      self: subpath:
      let
        user = self.user;
        profileType = helpers.profileTypeForUser user;
        configInput = additionalInputs.config;
        fullPath =
          configInput + "/profiles" + ("/" + profileType + "/" + user.profileName + "/files/" + subpath);
      in
      if builtins.pathExists fullPath then
        fullPath
      else
        throw "File not found: config/profiles/${profileType}/${user.profileName}/files/${subpath}";

    # Get relative path string to user profile secrets file
    # Usage: secretsRel $SELF $SUBPATH
    secretsRel =
      self: subpath:
      let
        user = self.user;
        profileType = helpers.profileTypeForUser user;
        configInput = additionalInputs.config;
        fullPath =
          configInput + "/profiles" + ("/" + profileType + "/" + user.profileName + "/secrets/" + subpath);
      in
      if builtins.pathExists fullPath then
        "config/profiles/${profileType}/${user.profileName}/secrets/${subpath}"
      else
        throw "Secret file not found: config/profiles/${profileType}/${user.profileName}/secrets/${subpath}";

    # Get relative path string to user profile files
    # Usage: filesRel $SELF $SUBPATH
    filesRel =
      self: subpath:
      let
        user = self.user;
        profileType = helpers.profileTypeForUser user;
        configInput = additionalInputs.config;
        fullPath =
          configInput + "/profiles" + ("/" + profileType + "/" + user.profileName + "/files/" + subpath);
      in
      if builtins.pathExists fullPath then
        "config/profiles/${profileType}/${user.profileName}/files/${subpath}"
      else
        throw "File not found: config/profiles/${profileType}/${user.profileName}/files/${subpath}";

    # Create symlink to user profile secrets file
    # Usage: symlinkSecrets $SELF $CONFIG $SUBPATH
    symlinkSecrets =
      self: config: subpath:
      let
        user = self.user;
        profileType = helpers.profileTypeForUser user;
        configSourcePath = helpers.getLocalSourcePath "config";
        relativePath =
          configSourcePath + "/profiles/" + profileType + "/" + user.profileName + "/secrets/" + subpath;
      in
      if
        builtins.pathExists (
          additionalInputs.config
          + "/profiles/"
          + profileType
          + "/"
          + user.profileName
          + "/secrets/"
          + subpath
        )
      then
        helpers.symlinkToHomeDirPath config relativePath
      else
        throw "Secret file not found: config/profiles/${profileType}/${user.profileName}/secrets/${subpath}";

    # Create symlink to user profile files
    # Usage: symlinkFiles $SELF $CONFIG $SUBPATH
    symlinkFiles =
      self: config: subpath:
      let
        user = self.user;
        profileType = helpers.profileTypeForUser user;
        configSourcePath = helpers.getLocalSourcePath "config";
        relativePath =
          configSourcePath + "/profiles/" + profileType + "/" + user.profileName + "/files/" + subpath;
      in
      if
        builtins.pathExists (
          additionalInputs.config + "/profiles/" + profileType + "/" + user.profileName + "/files/" + subpath
        )
      then
        helpers.symlinkToHomeDirPath config relativePath
      else
        throw "File not found: config/profiles/${profileType}/${user.profileName}/files/${subpath}";

    # Check if a user module is enabled by dotted path
    # Usage: self.user.isModuleEnabledByName "common.vim.nixvim"
    isModuleEnabledByName =
      self: path:
      let
        pathParts = lib.splitString "." path;
        modules = self.user.modules;
      in
      lib.hasAttrByPath pathParts modules;

    # Get config for user module by dotted path, returns {} if not found
    # Usage: self.user.getConfigForModuleByName "common.vim.nixvim"
    getConfigForModuleByName =
      self: path:
      let
        pathParts = lib.splitString "." path;
        modules = self.user.modules;
      in
      lib.attrByPath pathParts { } modules;

    # Require config for user module by dotted path, fails if not found
    # Usage: self.user.requireConfigForModuleByName "common.vim.nixvim"
    requireConfigForModuleByName =
      self: path:
      let
        pathParts = lib.splitString "." path;
        modules = self.user.modules;
      in
      if lib.hasAttrByPath pathParts modules then
        lib.attrByPath pathParts { } modules
      else
        throw "Required user module '${path}' is not enabled in user modules";
  };

  hostFuncs = {
    # Get absolute path to host profile secrets file
    # Usage: secrets $SELF $SUBPATH
    secrets =
      self: subpath:
      let
        host = self.host;
        configInput = additionalInputs.config;
        fullPath = configInput + "/profiles" + ("/nixos/" + host.profileName + "/secrets/" + subpath);
      in
      if builtins.pathExists fullPath then
        fullPath
      else
        throw "Secret file not found: config/profiles/nixos/${host.profileName}/secrets/${subpath}";

    # Get absolute path to host profile files
    # Usage: files $SELF $SUBPATH
    files =
      self: subpath:
      let
        host = self.host;
        configInput = additionalInputs.config;
        fullPath = configInput + "/profiles" + ("/nixos/" + host.profileName + "/files/" + subpath);
      in
      if builtins.pathExists fullPath then
        fullPath
      else
        throw "File not found: config/profiles/nixos/${host.profileName}/files/${subpath}";

    # Get relative path string to host profile secrets file
    # Usage: secretsRel $SELF $SUBPATH
    secretsRel =
      self: subpath:
      let
        host = self.host;
        configInput = additionalInputs.config;
        fullPath = configInput + "/profiles" + ("/nixos/" + host.profileName + "/secrets/" + subpath);
      in
      if builtins.pathExists fullPath then
        "config/profiles/nixos/${host.profileName}/secrets/${subpath}"
      else
        throw "Secret file not found: config/profiles/nixos/${host.profileName}/secrets/${subpath}";

    # Get relative path string to host profile files
    # Usage: filesRel $SELF $SUBPATH
    filesRel =
      self: subpath:
      let
        host = self.host;
        configInput = additionalInputs.config;
        fullPath = configInput + "/profiles" + ("/nixos/" + host.profileName + "/files/" + subpath);
      in
      if builtins.pathExists fullPath then
        "config/profiles/nixos/${host.profileName}/files/${subpath}"
      else
        throw "File not found: config/profiles/nixos/${host.profileName}/files/${subpath}";

    # Create symlink to host profile secrets file
    # Usage: symlinkSecrets $SELF $CONFIG $SUBPATH
    symlinkSecrets =
      self: config: subpath:
      let
        host = self.host;
        configSourcePath = helpers.getLocalSourcePath "config";
        relativePath = configSourcePath + "/profiles/nixos/" + host.profileName + "/secrets/" + subpath;
      in
      if
        builtins.pathExists (
          additionalInputs.config + "/profiles/nixos/" + host.profileName + "/secrets/" + subpath
        )
      then
        helpers.symlinkToHomeDirPath config relativePath
      else
        throw "Secret file not found: config/profiles/nixos/${host.profileName}/secrets/${subpath}";

    # Create symlink to host profile files
    # Usage: symlinkFiles $SELF $CONFIG $SUBPATH
    symlinkFiles =
      self: config: subpath:
      let
        host = self.host;
        configSourcePath = helpers.getLocalSourcePath "config";
        relativePath = configSourcePath + "/profiles/nixos/" + host.profileName + "/files/" + subpath;
      in
      if
        builtins.pathExists (
          additionalInputs.config + "/profiles/nixos/" + host.profileName + "/files/" + subpath
        )
      then
        helpers.symlinkToHomeDirPath config relativePath
      else
        throw "File not found: config/profiles/nixos/${host.profileName}/files/${subpath}";

    # Check if a host module is enabled by dotted path
    # Usage: self.host.isModuleEnabledByName "common.vim.nixvim"
    isModuleEnabledByName =
      self: path:
      let
        pathParts = lib.splitString "." path;
        modules = self.host.modules;
      in
      lib.hasAttrByPath pathParts modules;

    # Get config for host module by dotted path, returns {} if not found
    # Usage: self.host.getConfigForModuleByName "common.vim.nixvim"
    getConfigForModuleByName =
      self: path:
      let
        pathParts = lib.splitString "." path;
        modules = self.host.modules;
      in
      lib.attrByPath pathParts { } modules;

    # Require config for host module by dotted path, fails if not found
    # Usage: self.host.requireConfigForModuleByName "common.vim.nixvim"
    requireConfigForModuleByName =
      self: path:
      let
        pathParts = lib.splitString "." path;
        modules = self.host.modules;
      in
      if lib.hasAttrByPath pathParts modules then
        lib.attrByPath pathParts { } modules
      else
        throw "Required host module '${path}' is not enabled in host modules";
  };
}
