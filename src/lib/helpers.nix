{
  lib,
  defs,
  additionalInputs,
}:
rec {
  # Returns if building for native or compatible architecture
  isHostArchitecture = throw "isHostArchitecture must be overridden by localHelpers (processHostProfile/processStandaloneUserProfile)";

  # Null-safe value selection
  # Usage: ifSet $VALUE $DEFAULT
  ifSet = value: default: if value != null then value else default;

  # Deep-merge values with list concatenation and type checks.
  # Usage: deepMergeComplex { base = $BASE; override = $OVERRIDE; forbidNewRoot = $BOOL; forbidNewAny = $BOOL;  forbidNewDeep = $BOOL;}
  deepMergeComplex =
    {
      base,
      override,
      forbidNewRoot ? false,
      forbidNewAny ? false,
      forbidNewDeep ? false,
    }:
    let
      forbidRoot = forbidNewRoot || forbidNewAny;

      typeTag =
        value:
        if value == null then
          "null"
        else if lib.isDerivation value then
          "derivation"
        else
          builtins.typeOf value;

      renderPath = path: if path == [ ] then "<root>" else lib.concatStringsSep "." path;

      mergeAt =
        path: a: b:
        if a == null && b == null then
          null
        else if a == null then
          b
        else if b == null then
          a
        else if typeTag a != typeTag b then
          throw "Type mismatch while deep-merging at '${renderPath path}': ${typeTag a} vs ${typeTag b}!"
        else if lib.isDerivation a then
          b
        else if builtins.isList a then
          a ++ b
        else if builtins.isAttrs a then
          let
            newKeys = lib.filter (key: !(builtins.hasAttr key a)) (builtins.attrNames b);
            mustRejectNewKeys = forbidNewAny || (forbidRoot && path == [ ]) || (forbidNewDeep && path != [ ]);
          in
          if mustRejectNewKeys && newKeys != [ ] then
            throw "New attribute(s) introduced while deep-merging at '${renderPath path}': ${lib.concatStringsSep ", " newKeys}!"
          else
            lib.foldl' (
              acc: key:
              acc
              // {
                ${key} =
                  if builtins.hasAttr key acc then mergeAt (path ++ [ key ]) acc.${key} b.${key} else b.${key};
              }
            ) a (builtins.attrNames b)
        else
          b;
    in
    mergeAt [ ] base override;

  # Deep-merge values with list concatenation and type checks.
  # Usage: deepMerge $BASE $OVERRIDE
  deepMerge = base: override: deepMergeComplex { inherit base override; };

  # Wraps a when-condition check value to invert the comparison.
  # Usage: helpers.mkNot value
  mkNot = value: {
    __nxNot = true;
    inherit value;
  };

  # Resolve flake input path from input name
  # Usage: resolveInputFromInput $INPUT
  resolveInputFromInput =
    input:
    if additionalInputs ? ${input} then
      additionalInputs.${input}
    else
      throw "Unknown input '${input}'. Available inputs: ${builtins.toString (builtins.attrNames additionalInputs)}";

  # Check if input is local development input for live editing.
  # Only valid when called from within the module evaluation context (funcs.nix / moduleFuncs.nix),
  # not on the global helpers instance.
  # Usage: isLocalDevelopmentInput $INPUTPATH $INPUT
  isLocalDevelopmentInput = inputPath: input: defs.localDevelopmentInputs ? ${input};

  # Get local filesystem source path for development input.
  # Only valid when called from within the module evaluation context (funcs.nix / moduleFuncs.nix),
  # not on the global helpers instance.
  # Usage: getLocalSourcePath $INPUT
  getLocalSourcePath =
    input:
    if defs.localDevelopmentInputs ? ${input} then
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

  # Create symlink to file in any input; not allowed for core inputs
  # Usage: symlinkInputFile $CONFIG $INPUTNAME $SUBPATH
  symlinkInputFile =
    config: inputName: subPath:
    if builtins.elem inputName defs.coreInputs then
      throw "Symlinks to core inputs are not allowed (input '${inputName}')."
    else if (config.nx.global.deploymentMode or "develop") == "managed" then
      throw "Symlinks are not allowed in managed deployment mode!"
    else if isLocalDevelopmentInput null inputName then
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
      isVM ? false,
      host ? false,
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
            "systemd-tmpfiles-setup.service"
          ];

          excludeForVMUnits = [
            "acpid.service"
            "autovt@tty1.service"
            "rc-local.service"
            "systemd-machined.service"
            "suspend.target"
            "hibernate.target"
            "hybrid-sleep.target"
            "sleep.target"
          ];

          activeExcludes =
            (if isVM then excludeForVMUnits else [ ])
            ++ lib.optionals (host == null || !host.settings.networking.useNetworkManager) [
              "resolvconf.service"
            ]
            ++ lib.optionals (!(config.boot.plymouth.enable or false)) [
              "plymouth-quit.service"
              "plymouth-start.service"
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
          invalidRefsWithoutExcludes = builtins.filter (ref: !(lib.elem ref activeExcludes)) invalidRefs;
        in
        {
          assertion = invalidRefsWithoutExcludes == [ ];
          message = "SystemD ${context} units referenced but not found: ${builtins.concatStringsSep ", " invalidRefsWithoutExcludes}";
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

  # Parse semantic version string to list of integers (minimum 3 components)
  # Usage: parseVersion "3.6a" -> [3 6 0]
  parseVersion =
    versionStr:
    let
      extractLeadingDigits =
        str:
        let
          chars = lib.stringToCharacters str;
          isDigit =
            c:
            builtins.elem c [
              "0"
              "1"
              "2"
              "3"
              "4"
              "5"
              "6"
              "7"
              "8"
              "9"
            ];
          takeWhileDigit =
            chars:
            if chars == [ ] then
              [ ]
            else if isDigit (builtins.head chars) then
              [ (builtins.head chars) ] ++ (takeWhileDigit (builtins.tail chars))
            else
              [ ];
          digitChars = takeWhileDigit chars;
        in
        if digitChars == [ ] then "0" else lib.concatStrings digitChars;

      stripPrerelease =
        str:
        let
          dashPos = lib.strings.splitString "-" str;
          plusPos = lib.strings.splitString "+" (builtins.head dashPos);
        in
        builtins.head plusPos;

      coreVersion = stripPrerelease versionStr;
      parts = lib.splitString "." coreVersion;
      cleanParts = map (part: lib.toInt (extractLeadingDigits part)) parts;
      minComponents = 3;
      paddingNeeded = lib.max 0 (minComponents - (builtins.length cleanParts));
      padding = lib.genList (_: 0) paddingNeeded;
    in
    if versionStr == "" then throw "Cannot parse empty version string" else cleanParts ++ padding;

  # Compare two version lists element by element
  # Usage: compareVersions [3 3 5] [4 2 2] -> -1 (less), 0 (equal), 1 (greater)
  compareVersions =
    v1: v2:
    let
      maxLen = lib.max (builtins.length v1) (builtins.length v2);
      padVersion =
        v: len:
        let
          currentLen = builtins.length v;
          padding = lib.genList (_: 0) (len - currentLen);
        in
        v ++ padding;

      v1Padded = padVersion v1 maxLen;
      v2Padded = padVersion v2 maxLen;

      compareElements =
        i:
        if i >= maxLen then
          0
        else
          let
            e1 = builtins.elemAt v1Padded i;
            e2 = builtins.elemAt v2Padded i;
          in
          if e1 < e2 then
            -1
          else if e1 > e2 then
            1
          else
            compareElements (i + 1);
    in
    compareElements 0;

  # Select package from stable or unstable based on version predicate
  # Usage: usePackageByVersionCheck args "tmuxinator" (version: compareVersions (parseVersion version) (parseVersion "3.3.7") >= 0)
  usePackageByVersionCheck =
    args: pkgName: predicate:
    let
      unstablePkgs = args.pkgs-unstable or { };

      stablePkg = args.pkgs.${pkgName} or null;
      unstablePkg = unstablePkgs.${pkgName} or null;

      hasStable = stablePkg != null;
      hasUnstable = unstablePkg != null;
      stableHasVersion = hasStable && stablePkg ? version;
      unstableHasVersion = hasUnstable && unstablePkg ? version;

      evaluatePackage =
        pkg: hasVersion:
        if !hasVersion then
          {
            acceptable = false;
            canCompare = false;
          }
        else
          let
            evalResult = builtins.tryEval (predicate pkg.version);
          in
          if evalResult.success then
            {
              acceptable = evalResult.value;
              canCompare = true;
            }
          else
            {
              acceptable = false;
              canCompare = false;
            };

      stableEval = evaluatePackage stablePkg stableHasVersion;
      unstableEval = evaluatePackage unstablePkg unstableHasVersion;

      result =
        if !hasStable && !hasUnstable then
          throw "Package '${pkgName}' not found in stable or unstable"
        else if !hasUnstable then
          if !stableEval.canCompare then
            throw "Package '${pkgName}' version cannot be parsed in stable and unstable is not available"
          else if stableEval.acceptable then
            stablePkg
          else
            throw "Package '${pkgName}' in stable does not meet version requirement and unstable is not available"
        else if !hasStable then
          if !unstableEval.canCompare then
            unstablePkg
          else if unstableEval.acceptable then
            unstablePkg
          else
            throw "Package '${pkgName}' in unstable does not meet version requirement"
        else if !stableEval.canCompare then
          throw "Package '${pkgName}' version cannot be parsed in stable"
        else if stableEval.acceptable then
          stablePkg
        else if !unstableEval.canCompare then
          unstablePkg
        else if unstableEval.acceptable then
          unstablePkg
        else
          throw "Package '${pkgName}' does not meet version requirement in stable or unstable";
    in
    result;

  # Select package that meets minimum version requirement
  # Usage: requireMinimumPackageVersion args "tmuxinator" "3.3.7"
  requireMinimumPackageVersion =
    args: pkgName: minVersion:
    let
      minVersionParsed = parseVersion minVersion;
      predicate =
        version:
        let
          currentVersionParsed = parseVersion version;
          comparison = compareVersions currentVersionParsed minVersionParsed;
        in
        comparison >= 0;
    in
    usePackageByVersionCheck args pkgName predicate;

  # Select package within version range (min inclusive, max exclusive)
  # Usage: requirePackageVersionInRange args "tmuxinator" "3.0.0" "4.0.0"
  requirePackageVersionInRange =
    args: pkgName: minVersion: maxVersion:
    let
      minVersionParsed = parseVersion minVersion;
      maxVersionParsed = parseVersion maxVersion;
      predicate =
        version:
        let
          currentVersionParsed = parseVersion version;
          minComparison = compareVersions currentVersionParsed minVersionParsed;
          maxComparison = compareVersions currentVersionParsed maxVersionParsed;
        in
        minComparison >= 0 && maxComparison < 0;
    in
    usePackageByVersionCheck args pkgName predicate;

  # Prepend absolute path to binary in command list or function result
  # Respects commandIsAbsolute flag (returns unchanged if true)
  # Usage: runWithAbsolutePath config textEditor textEditor.openCommand []
  # Usage: runWithAbsolutePath config textEditor textEditor.openFileCommand file
  runWithAbsolutePath =
    config: program: function: args:
    let
      isCallable = builtins.isFunction function || (builtins.isAttrs function && function ? __functor);
      result = if isCallable then function args else function;
    in
    if program.commandIsAbsolute or false then
      result
    else
      let
        basePath =
          if program.localBin or false then
            config.home.homeDirectory + "/.local/bin/"
          else if program.package == null then
            throw "program ${program.name} must have a package or commandIsAbsolute set!"
          else
            program.package + "/bin/";
      in
      if builtins.isList result then
        [ (basePath + (builtins.head result)) ] ++ (builtins.tail result)
      else
        basePath + result;

  # Returns terminal.openRunPrefix with absolute path if program.needsTerminal is true, else empty list
  # Usage: (terminalPrefixIf config textEditor) ++ textEditor.openCommand ++ [ "{file}" ]
  terminalPrefixIf =
    config: program:
    if program.needsTerminal or false then
      let
        terminal = config.nx.preferences.desktop.programs.terminal;
      in
      runWithAbsolutePath config terminal terminal.openRunPrefix [ ]
    else
      [ ];

  # Returns additionalTerminal.openRunPrefix with absolute path if program.needsTerminal is true, else empty list
  # Usage: (additionalTerminalPrefixIf config textEditor) ++ textEditor.openCommand ++ [ "{file}" ]
  additionalTerminalPrefixIf =
    config: program:
    if program.needsTerminal or false then
      let
        terminal = config.nx.preferences.desktop.programs.additionalTerminal;
      in
      runWithAbsolutePath config terminal terminal.openRunPrefix [ ]
    else
      [ ];

  icons = {
    # Checks that the icon name is registered in config.nx.lib.icons and returns it.
    # When no icons are declared, returns name without validation.
    # Usage: getIcon config "icon-name"
    getIcon =
      config: name:
      let
        declared = config.nx.lib.icons;
        flat = lib.concatMap (e: if builtins.isList e then e else [ e ]) declared;
      in
      if declared == [ ] || builtins.elem name flat then
        name
      else
        builtins.throw "nx icons: '${name}' not found in config.nx.lib.icons";

    # Splits pattern on '|', returns the pattern if any icon was found in config.nx.lib.icons.
    # When no icons are declared, returns the first name in the pattern.
    # Usage: searchIcon config "icon-pattern"
    searchIcon =
      config: pattern:
      let
        declared = config.nx.lib.icons;
        flat = lib.concatMap (e: if builtins.isList e then e else [ e ]) declared;
        names = lib.splitString "|" pattern;
        result = lib.findFirst (name: builtins.elem name flat) null names;
      in
      if declared == [ ] || result != null then
        pattern
      else
        builtins.throw "nx icons: no icon found for '${pattern}' in config.nx.lib.icons";
  };

  # Converts a systemlog logger level to a notify-send level.
  # Usage: loggerLevelToNotifyLevel "info"
  loggerLevelToNotifyLevel =
    level:

    if level == "info" then
      "normal"
    else if level == "warning" then
      "normal"
    else if level == "err" || level == "error" then
      "critical"
    else
      throw "loggerLevelToNotifyLevel: unknown level '${level}'";

  isModulesOnlyInput = inputName: builtins.elem inputName defs.modulesOnlyInputs;

  allModuleInputsToScan =
    let
      extraInputNames = builtins.filter (name: !(builtins.elem name defs.moduleInputsToScan)) (
        builtins.attrNames additionalInputs
      );
    in
    defs.moduleInputsToScan ++ extraInputNames;

  buildModuleDir =
    inputName: groupName: moduleName:
    if isModulesOnlyInput inputName then
      "${groupName}/${moduleName}"
    else
      "modules/${groupName}/${moduleName}";

  buildModuleFilePath =
    inputPath: inputName: groupName: moduleName:
    if isModulesOnlyInput inputName then
      inputPath + "/${groupName}/${moduleName}.nix"
    else
      inputPath + "/modules/${groupName}/${moduleName}.nix";

  getDiskoResumeDevices =
    diskoDevices:
    let
      lvmVgs = diskoDevices.lvm_vg or { };
    in
    lib.flatten (
      lib.mapAttrsToList (
        vgName: vg:
        lib.mapAttrsToList (
          lvName: lv:
          if (lv.content.type or "") == "swap" && (lv.content.resumeDevice or false) == true then
            [ "/dev/${vgName}/${lvName}" ]
          else
            [ ]
        ) (vg.lvs or { })
      ) lvmVgs
    );
}
