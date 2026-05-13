args@{
  lib,
  pkgs,
  pkgs-unstable,
  inputs,
  host,
  user,
  funcs,
  helpers,
  defs,
  variables,
  ...
}:
let
  initialModules = user.modules or { };
  buildModules =
    lib.recursiveUpdate
      {
        groups.build.home-standalone = true;
        groups.build.shared = true;
      }
      (
        if user.addBaseGroup then
          {
            groups.base.home-manager = true;
          }
        else
          { }
      );
  extraContextModules = funcs.collectContextEnabledModules args;
  allModules = funcs.collectAllModulesWithSettings args initialModules (
    lib.recursiveUpdate buildModules extraContextModules
  );

  moduleSpecs = funcs.processModules allModules;
  moduleResults = funcs.importModules args moduleSpecs allModules "home-standalone";

  extraModules = moduleResults.modules;

  allModuleData = funcs.collectAllModuleData args;
  optionsModules = funcs.generateOptionsModules allModuleData;
  settingsValueModules = funcs.generateSettingsValueModules allModuleData allModules;
  optionsValueModules = funcs.generateOptionsValueModules allModuleData allModules;
  enableValueModules = funcs.generateEnableValueModules allModuleData allModules;
  metaValueModules = funcs.generateMetaValueModules allModuleData;

  initModules = funcs.importAllModuleInits (args // { processedModules = allModules; });
  disabledModules = funcs.importAllModuleDisableds (args // { processedModules = allModules; });

  specialisationConfigs = builtins.mapAttrs (specName: specModules: {
    configuration = {
      imports =
        (funcs.importModules args (funcs.processModules specModules) allModules "home-standalone").modules;
    };
  }) (user.specialisations or { });

  extraUserModule =
    if (user.extraModulePath or null) != null && builtins.pathExists user.extraModulePath then
      [ (import user.extraModulePath args) ]
    else
      [ ];

  userProfileModule = funcs.processProfileModule {
    profile = user;
    profileType = "home-standalone";
    profileName = user.profileName;
    args = args;
    processedModules = allModules;
    buildContext = "home-standalone";
  };

  profileInitModules = userProfileModule.initModules;
  profileContextModules = userProfileModule.contextModules;

  mkNxDef =
    extraCommands:
    import (inputs.lib + "/cmds.nix") {
      inherit lib extraCommands;
      architectures = import inputs.nix-systems;
      rootPath = defs.rootPath;
      scope = "standalone";
      system = if pkgs.stdenv.isDarwin then "darwin" else "linux";
      mode = user.deploymentMode or "develop";
    };

  nxCliEnabled = (user.deploymentMode or "develop") != "managed";
in
{ config, options, ... }:
let
  nxDef = mkNxDef config.nx.commandline;
in
{
  imports =
    optionsModules
    ++ settingsValueModules
    ++ optionsValueModules
    ++ enableValueModules
    ++ metaValueModules
    ++ initModules
    ++ disabledModules
    ++ profileInitModules
    ++ extraModules
    ++ extraUserModule
    ++ profileContextModules
    ++ [
      (import ../../assertions/home/home-standalone.nix (args // { processedModules = allModules; }))
      (import ../../assertions/home/shared.nix (args // { processedModules = allModules; }))
    ];

  specialisation = specialisationConfigs;

  home = {
    username = user.username;

    packages =
      (user.additionalPackages or [ ])
      ++ lib.optionals nxCliEnabled [
        (pkgs.stdenv.mkDerivation {
          name = "nx";
          src = builtins.path {
            path = defs.rootPath;
            name = "nx-source";
            filter =
              path: type:
              let
                baseName = builtins.baseNameOf path;
              in
              baseName == "nx"
              || baseName == "scripts"
              || lib.hasPrefix (toString defs.rootPath + "/scripts/") (toString path);
          };
          dontAuditTmpdir = true;
          installPhase = ''
                      mkdir -p $out/bin $out/share/nx/scripts/utils
                      cp -r scripts $out/share/nx/
                      cp nx $out/share/nx/
                      chmod +x $out/share/nx/scripts/utils/nx-help-formatter.py

                      find $out/share/nx/scripts -type f -exec sh -c '
                        if head -1 "$1" 2>/dev/null | grep -q "^#!/usr/bin/env bash"; then
                          chmod +w "$1"
                          sed -i "1s|#!/usr/bin/env bash|#!${pkgs.bash}/bin/bash|" "$1"
                          chmod -w "$1"
                        fi
                      ' _ {} \;

                      if head -1 $out/share/nx/nx 2>/dev/null | grep -q "^#!/usr/bin/env bash"; then
                        chmod +w $out/share/nx/nx
                        sed -i "1s|#!/usr/bin/env bash|#!${pkgs.bash}/bin/bash|" $out/share/nx/nx
                        chmod -w $out/share/nx/nx
                      fi

                      cat > $out/bin/nx << EOF
            #!${pkgs.bash}/bin/bash
            export ACTUAL_PWD="\$PWD"
            export NX_INSTALL_PATH="$out/share/nx"
            cd $out/share/nx
            exec $out/share/nx/nx "\$@"
            EOF
                      chmod +x $out/bin/nx

                      cp ${pkgs.writeText "nx-spec.json" nxDef.json} $out/share/nx/nx-spec.json
          '';
        })
        pkgs.jq
      ];

    file = lib.optionalAttrs nxCliEnabled (
      lib.optionalAttrs (config.programs.fish.enable or false) {
        ".config/fish/completions/nx.fish".text = nxDef.fish;
      }
      // lib.optionalAttrs (config.programs.bash.enable or false) {
        ".local/share/bash-completion/completions/nx".text = nxDef.bash;
      }
      // lib.optionalAttrs (config.programs.zsh.enable or false) {
        ".local/share/zsh/site-functions/_nx".text = nxDef.zsh;
      }
    );

    sessionVariables = lib.optionalAttrs nxCliEnabled {
      NXCORE_DIR = "$HOME/.config/nx/nxcore";
      NXCONFIG_DIR = "$HOME/.config/nx/nxconfig";
    };

    homeDirectory = user.home;

    stateVersion = if user.stateVersion != null then user.stateVersion else variables.state-version;
  };

  programs = {
    home-manager = {
      enable = true;
    };

    nh.enable = true;
  };

  nix = {
    settings = {
      experimental-features = variables.experimental-features;
      allow-import-from-derivation = false;
    };

    package = pkgs.nix;
  };
}
