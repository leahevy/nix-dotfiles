args@{
  lib,
  pkgs,
  allOverlays,
  unfreePredicate,
  inputs,
  host,
  user,
  funcs,
  helpers,
  defs,
  variables,
  processedModules,
  ...
}:
let
  allModules = processedModules;

  extraUserModule =
    if (user.extraModulePath or null) != null && builtins.pathExists user.extraModulePath then
      [ (import user.extraModulePath args) ]
    else
      [ ];

  contextModules = funcs.buildContextModules {
    args = args;
    processedModules = allModules;
    buildContext = "home-integrated";
    profiles = [
      {
        profile = host;
        profileType = "nixos";
        profileName = host.profileName;
      }
      {
        profile = user;
        profileType = "home-integrated";
        profileName = user.profileName;
      }
    ];
    specialisations = user.specialisations or { };
    extraUserModule = extraUserModule;
    assertionModules = [
      (import ../../assertions/home/home-integrated.nix (args // { processedModules = allModules; }))
      (import ../../assertions/home/shared.nix (args // { processedModules = allModules; }))
    ];
  };

  mkNxDef =
    extraCommands:
    import (inputs.lib + "/cmds.nix") {
      inherit lib extraCommands;
      architectures = import inputs.nix-systems;
      rootPath = defs.rootPath;
      scope = "integrated";
      system = if pkgs.stdenv.isDarwin then "darwin" else "linux";
      mode = host.deploymentMode or "develop";
    };

  nxCliEnabled = (host.deploymentMode or "develop") != "managed";
in
{ config, options, ... }:
let
  nxDef = mkNxDef config.nx.commandline;
in
{
  imports = contextModules.imports;

  specialisation = contextModules.specialisationConfigs;

  home = {
    username = user.username;

    packages =
      (user.additionalPackages or [ ])
      ++ (
        if user.isMainUser && nxCliEnabled then
          [
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
          ]
          ++ (with pkgs; [ jq ])
        else
          [ ]
      );

    file = lib.optionalAttrs (user.isMainUser && nxCliEnabled) (
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

    sessionVariables = (
      if user.isMainUser && nxCliEnabled then
        {
          NXCORE_DIR = "$HOME/.config/nx/nxcore";
          NXCONFIG_DIR = "$HOME/.config/nx/nxconfig";
        }
      else
        { }
    );

    homeDirectory = user.home;

    stateVersion = if host.stateVersion != null then host.stateVersion else variables.state-version;
  };

  programs = {
    home-manager = {
      enable = true;
    };
  };

  nixpkgs = {
    config.allowUnfreePredicate = unfreePredicate;
    overlays = allOverlays;
  };

  nix = {
    settings = {
      experimental-features = variables.experimental-features;
    };
  };
}
