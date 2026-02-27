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
  allModules = funcs.collectAllModulesWithSettings args initialModules "home";

  moduleSpecs = funcs.processModules allModules;
  moduleResults = funcs.importHomeModules args moduleSpecs allModules;

  extraModules = moduleResults.modules;

  specialisationConfigs = builtins.mapAttrs (specName: specModules: {
    configuration = {
      imports = (funcs.importHomeModules args (funcs.processModules specModules) allModules).modules;
    };
  }) (user.specialisations or { });

  extraUserModule =
    if (user.extraModulePath or null) != null && builtins.pathExists user.extraModulePath then
      [ (import user.extraModulePath args) ]
    else
      [ ];
in
{ config, options, ... }:

{
  imports =
    extraModules
    ++ extraUserModule
    ++ [
      (import ../../assertions/home/home-standalone.nix (args // { processedModules = allModules; }))
    ];

  specialisation = specialisationConfigs;

  home = {
    username = user.username;

    packages =
      (user.additionalPackages or [ ])
      ++ [
        (pkgs.stdenv.mkDerivation {
          name = "nx";
          src = defs.rootPath;
          dontAuditTmpdir = true;
          installPhase = ''
                      mkdir -p $out/bin $out/share/nx
                      cp -r scripts $out/share/nx/
                      cp nx $out/share/nx/

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
          '';
        })
      ]
      ++ (with pkgs; [ jq ]);

    file =
      lib.optionalAttrs (config.programs.fish.enable or false) {
        ".config/fish/completions/nx.fish".source = defs.rootPath + "/completions/nx.fish";
      }
      // lib.optionalAttrs (config.programs.bash.enable or false) {
        ".local/share/bash-completion/completions/nx".source = defs.rootPath + "/completions/nx.bash";
      }
      // lib.optionalAttrs (config.programs.zsh.enable or false) {
        ".local/share/zsh/site-functions/_nx".source = defs.rootPath + "/completions/nx.zsh";
      };

    sessionVariables = {
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
      http-connections = variables.httpConnections;
      keep-outputs = true;
      keep-derivations = true;
    };

    package = pkgs.nix;
  };
}
