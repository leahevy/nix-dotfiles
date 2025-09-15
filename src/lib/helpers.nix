{
  lib,
  defs,
  additionalInputs,
}:
rec {
  # Null-safe value selection
  # Usage: ifSet $VALUE $DEFAULT
  ifSet = value: default: if value != null then value else default;

  # Resolve flake input path from input name
  # Usage: resolveInputFromInput $INPUT
  resolveInputFromInput =
    input:
    if additionalInputs ? ${input} then
      additionalInputs.${input}
    else
      throw "Unknown input '${input}'. Available inputs: ${builtins.toString (builtins.attrNames additionalInputs)}";

  # Check if input is local development input for live editing
  # Usage: isLocalDevelopmentInput $INPUTPATH $INPUT
  isLocalDevelopmentInput =
    inputPath: input: defs.localDevelopmentInputs ? ${input} || input == "profile";

  # Get local filesystem source path for development input
  # Usage: getLocalSourcePath $INPUT
  getLocalSourcePath =
    input:
    if input == "profile" then
      toString additionalInputs.profile
    else if defs.localDevelopmentInputs ? ${input} then
      defs.localDevelopmentInputs.${input}
    else
      throw "Input '${input}' is not a local development input and has no source path";

  # Determine profile type based on user standalone setting
  # Usage: profileTypeForUser $USER
  profileTypeForUser =
    user: if (user.isStandalone or false) then "home-standalone" else "home-integrated";

  # Check if architecture is Linux
  # Usage: isLinuxArch $ARCHITECTURE
  isLinuxArch = architecture: lib.strings.hasSuffix "-linux" architecture;

  # Check if architecture is Darwin/macOS
  # Usage: isDarwinArch $ARCHITECTURE
  isDarwinArch = architecture: lib.strings.hasSuffix "-darwin" architecture;

  # Check if architecture is x86_64
  # Usage: isX86_64Arch $ARCHITECTURE
  isX86_64Arch = architecture: lib.strings.hasPrefix "x86_64-" architecture;

  # Check if architecture is AArch64 (ARM64)
  # Usage: isAARCH64Arch $ARCHITECTURE
  isAARCH64Arch = architecture: lib.strings.hasPrefix "aarch64-" architecture;

  # Create symlink to absolute path
  # Usage: symlink $CONFIG $SUBPATH
  symlink = config: subpath: config.lib.file.mkOutOfStoreSymlink subpath;

  # Create symlink to path relative to home directory
  # Usage: symlinkToHomeDirPath $CONFIG $SUBPATH
  symlinkToHomeDirPath =
    config: subpath: (config.lib.file.mkOutOfStoreSymlink (config.home.homeDirectory + "/" + subpath));

  # Validate required options are not null with error messages
  # Usage: assertNotNull $PROFILETYPE $OBJ $REQUIREDPATHS
  assertNotNull =
    profileType: obj: requiredPaths:
    let
      getNestedValue =
        path: obj:
        let
          parts = lib.splitString "." path;
          getValue =
            obj: parts:
            if parts == [ ] then
              obj
            else if builtins.hasAttr (builtins.head parts) obj then
              getValue (obj.${builtins.head parts}) (builtins.tail parts)
            else
              null;
        in
        getValue obj parts;

      checkPath =
        path:
        let
          value = getNestedValue path obj;
          fullPath = "${profileType}.${path}";
        in
        {
          assertion = value != null;
          message = "Required option '${fullPath}' cannot be null. Please set a value in your profile configuration.";
        };
    in
    map checkPath requiredPaths;

  # Generate a UUID from a given text input
  # Usage: generateUUID $TEXT
  generateUUID =
    text:
    let
      hash = builtins.hashString "sha256" text;
    in
    "${builtins.substring 0 8 hash}-${builtins.substring 8 4 hash}-${builtins.substring 12 4 hash}-${builtins.substring 16 4 hash}-${builtins.substring 20 12 hash}";

  # Get absolute path to file in any input
  # Usage: getInputFilePath $INPUT $SUBPATH
  getInputFilePath = input: subPath: input + "/" + subPath;

  # Get relative path string to file in input
  # Usage: getInputFilePathRel $INPUTNAME $SUBPATH
  getInputFilePathRel =
    inputName: subPath:
    if isLocalDevelopmentInput null inputName then
      (getLocalSourcePath inputName) + "/" + subPath
    else
      throw "Cannot get relative path for non-local input '${inputName}'";

  # Create symlink to file in any input
  # Usage: symlinkInputFile $CONFIG $INPUTNAME $SUBPATH
  symlinkInputFile =
    config: inputName: subPath:
    if isLocalDevelopmentInput null inputName then
      symlink config ((getLocalSourcePath inputName) + "/" + subPath)
    else
      throw "Cannot create symlink for non-local input '${inputName}'";
}
