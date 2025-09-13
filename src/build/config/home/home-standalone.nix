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
  buildModules = {
    build = {
      core = {
        programs = true;
        utils = true;
      };
      system = {
        dummy-files = true;
      };
    };
  };

  initialModules = lib.recursiveUpdate (user.modules or { }) buildModules;
  allModules = funcs.collectAllModulesWithSettings args initialModules "home";

  moduleSpecs = funcs.processModules allModules;
  moduleResults = funcs.importHomeModules args moduleSpecs;

  extraModules = moduleResults.modules;

  specialisationConfigs = builtins.mapAttrs (specName: specModules: {
    configuration = {
      imports = (funcs.importHomeModules args (funcs.processModules specModules)).modules;
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

  sops = {
    age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
    defaultSopsFile = helpers.secretsPathFromInput "config" "standalone-secrets.yaml";
    secrets = {
      github_token = {
        sopsFile = helpers.secretsPathFromInput "config" "global-secrets.yaml";
        path = "${config.xdg.configHome}/nix/github-token";
      };
    };
  };

  home = {
    username = user.username;

    packages =
      (user.additionalPackages or [ ])
      ++ [
        (pkgs.stdenv.mkDerivation {
          name = "nx";
          src = defs.rootPath;
          installPhase = ''
                      mkdir -p $out/bin $out/share/nx
                      cp -r scripts $out/share/nx/
                      cp nx $out/share/nx/
                      
                      cat > $out/bin/nx << EOF
            #!/usr/bin/env bash
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
    };

    extraOptions = ''
      !include ${config.xdg.configHome}/nix/github-token
    '';
    package = pkgs.nix;
  };
}
