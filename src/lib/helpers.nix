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

  # Validate systemd unit references in configuration
  # Usage: validateSystemdReferences { config, architecture, context, osConfig ? {} }
  validateSystemdReferences =
    {
      config,
      architecture,
      context,
      osConfig ? { },
    }:
    let
      isLinux = isLinuxArch architecture;

      systemdConfig = if context == "system" then config.systemd or { } else config.systemd.user or { };

      osSystemdUserConfig =
        if context == "user" && osConfig != { } && isLinux then osConfig.systemd.user or { } else { };

      extractSystemdReferences =
        config:
        let
          extractFromAttr =
            attr:
            if builtins.isString attr then
              if lib.hasSuffix ".service" attr then
                [ attr ]
              else if lib.hasSuffix ".target" attr then
                [ attr ]
              else if lib.hasSuffix ".timer" attr then
                [ attr ]
              else
                [ ]
            else if builtins.isList attr then
              lib.flatten (map extractFromAttr attr)
            else if builtins.isAttrs attr then
              lib.flatten (lib.mapAttrsToList (_: v: extractFromAttr v) attr)
            else
              [ ];

          currentSystemdConfig =
            if context == "system" then config.systemd or { } else config.systemd.user or { };

          extractFromService =
            service:
            if context == "system" then
              extractFromAttr (service.after or [ ])
              ++ extractFromAttr (service.requires or [ ])
              ++ extractFromAttr (service.wants or [ ])
              ++ extractFromAttr (service.wantedBy or [ ])
            else
              extractFromAttr (service.Unit.After or [ ])
              ++ extractFromAttr (service.Unit.Requires or [ ])
              ++ extractFromAttr (service.Unit.Wants or [ ])
              ++ extractFromAttr (service.Install.WantedBy or [ ]);

          extractFromTimer =
            timer:
            if context == "system" then
              extractFromAttr (timer.wantedBy or [ ])
            else
              extractFromAttr (timer.Install.WantedBy or [ ]);

          serviceRefs = lib.flatten (
            lib.mapAttrsToList (_: service: extractFromService service) (currentSystemdConfig.services or { })
          );
          timerRefs = lib.flatten (
            lib.mapAttrsToList (_: timer: extractFromTimer timer) (currentSystemdConfig.timers or { })
          );
        in
        lib.unique (serviceRefs ++ timerRefs);

      validateReferences =
        references:
        let
          genericUnits = [
            "basic.target"
            "default.target"
            "network.target"
            "paths.target"
            "shutdown.target"
            "sockets.target"
            "timers.target"
          ];

          userUnits = [
            "graphical-session.target"
            "niri.service"
          ];

          baseSystemUnits = [
            "bluetooth.target"
            "graphical.target"
            "halt.target"
            "kexec.target"
            "network-online.target"
            "network-pre.target"
            "nss-lookup.target"
            "nss-user-lookup.target"
            "poweroff.target"
            "reboot.target"
            "suspend-then-hibernate.target"
            "sysinit.target"
            "systemd-sysusers.service"
          ];

          userServices =
            if context == "system" then
              map (user: "user@${toString user.uid}.service") (builtins.attrValues (config.users.users or { }))
            else
              [ ];

          systemUnits = baseSystemUnits ++ userServices;

          knownUnits = genericUnits ++ (if context == "system" then systemUnits else userUnits);

          isKnownUnit = ref: builtins.elem ref knownUnits;
          checkReference =
            ref:
            if isKnownUnit ref then
              true
            else if lib.hasSuffix ".service" ref then
              let
                unitName = lib.removeSuffix ".service" ref;
              in
              (systemdConfig.services or { }) ? ${unitName} || (osSystemdUserConfig.services or { }) ? ${unitName}
            else if lib.hasSuffix ".target" ref then
              let
                unitName = lib.removeSuffix ".target" ref;
              in
              (systemdConfig.targets or { }) ? ${unitName} || (osSystemdUserConfig.targets or { }) ? ${unitName}
            else if lib.hasSuffix ".timer" ref then
              let
                unitName = lib.removeSuffix ".timer" ref;
              in
              (systemdConfig.timers or { }) ? ${unitName} || (osSystemdUserConfig.timers or { }) ? ${unitName}
            else
              true;

          invalidRefs = builtins.filter (ref: !(checkReference ref)) references;
        in
        {
          assertion = invalidRefs == [ ];
          message = "SystemD ${context} units referenced but not found: ${builtins.concatStringsSep ", " invalidRefs}";
        };

      systemdRefs = extractSystemdReferences config;
    in
    if isLinux && systemdRefs != [ ] then [ (validateReferences systemdRefs) ] else [ ];

  # Create MacOS .app application bundle
  # Usage: createTerminalDarwinApp pkgs { name, terminalApp, execArgs, icon ? null }
  createTerminalDarwinApp =
    pkgs:
    {
      name,
      terminalApp,
      execArgs,
      icon ? null,
    }:
    let
      minimizedAppName = lib.strings.toLower (lib.strings.replaceStrings [ " " "/" ] [ "-" "-" ] name);
      infoPlist = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
          <dict>
            <key>CFBundleName</key><string>${name}</string>
            <key>CFBundleIdentifier</key><string>org.nx.${minimizedAppName}</string>
            <key>CFBundleExecutable</key><string>launcher</string>
            <key>CFBundleIconFile</key><string>app.icns</string>
            <key>CFBundlePackageType</key><string>APPL</string>
            <key>CFBundleVersion</key><string>0.1</string>
          </dict>
        </plist>
      '';

      launcher = ''
        #!/usr/bin/env bash
        source ~/.nix-profile/etc/profile.d/hm-session-vars.sh 2>/dev/null || true
        /usr/bin/open -na "${terminalApp}" --args -e ${execArgs}
      '';
    in
    pkgs.runCommand "${minimizedAppName}-darwin-app"
      {
        buildInputs = [ ];
        passthru.appName = "${name}.app";
      }
      ''
        mkdir -p "$out/Applications/${name}.app/Contents/"{MacOS,Resources}

        echo '${infoPlist}' > "$out/Applications/${name}.app/Contents/Info.plist"

        echo '${launcher}' > "$out/Applications/${name}.app/Contents/MacOS/launcher"
        chmod +x "$out/Applications/${name}.app/Contents/MacOS/launcher"

        ${
          if (icon != null) then
            ''
              cp "${icon}" "$out/Applications/${name}.app/Contents/Resources/app.icns"
            ''
          else
            ''
              if [ -f "${pkgs.alacritty}/Applications/Alacritty.app/Contents/Resources/alacritty.icns" ]; then
                cp "${pkgs.alacritty}/Applications/Alacritty.app/Contents/Resources/alacritty.icns" \
                   "$out/Applications/${name}.app/Contents/Resources/app.icns"
              else
                touch "$out/Applications/${name}.app/Contents/Resources/app.icns"
              fi
            ''
        }
      '';
}
