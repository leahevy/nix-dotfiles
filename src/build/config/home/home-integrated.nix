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
        tokens = true;
        sops = true;
      };
      system = {
        dummy-files = true;
      }
      // (if host.impermanence or false then { impermanence = true; } else { });
    };
  };

  initialModules = lib.foldl lib.recursiveUpdate { } [
    (user.modules or { })
    (host.userDefaults.modules or { })
    buildModules
  ];
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
    let
      buildModules =
        if (user.extraModulePath or null) != null && builtins.pathExists user.extraModulePath then
          [ (import user.extraModulePath args) ]
        else
          [ ];

      virtualModule =
        if user.configuration != (args: context: { }) then
          let
            moduleContext = {
              inputs = inputs;
              variables = variables;
              configInputs = args.configInputs or { };
              moduleBasePath = "profiles/home-integrated/${user.profileName}";
              moduleInput = args.configInputs.config or inputs.config;
              moduleInputName = "config";
              user = user;
              host = host;
              persist = "${variables.persist.home}/${user.username}";
            };

            enhancedContext =
              moduleContext
              // (lib.mapAttrs (name: func: func moduleContext) funcs.moduleFuncs.commonFuncs)
              // {
                user =
                  moduleContext.user // (lib.mapAttrs (name: func: func moduleContext) funcs.moduleFuncs.userFuncs);
              };

            enhancedArgs = args // {
              self = enhancedContext;
            };
          in
          [ (user.configuration enhancedArgs) ]
        else
          [ ];
    in
    buildModules ++ virtualModule;
in
{ config, options, ... }:

{
  imports =
    extraModules
    ++ extraUserModule
    ++ [
      (import ../../assertions/home/home-integrated.nix (args // { processedModules = allModules; }))
    ];

  specialisation = specialisationConfigs;

  home = {
    username = user.username;

    packages =
      (user.additionalPackages or [ ])
      ++ (
        if user.isMainUser then
          [
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
          ++ (with pkgs; [ jq ])
        else
          [ ]
      );

    file = lib.optionalAttrs user.isMainUser (
      lib.optionalAttrs (config.programs.fish.enable or false) {
        ".config/fish/completions/nx.fish".source = defs.rootPath + "/completions/nx.fish";
      }
      // lib.optionalAttrs (config.programs.bash.enable or false) {
        ".local/share/bash-completion/completions/nx".source = defs.rootPath + "/completions/nx.bash";
      }
      // lib.optionalAttrs (config.programs.zsh.enable or false) {
        ".local/share/zsh/site-functions/_nx".source = defs.rootPath + "/completions/nx.zsh";
      }
    );

    sessionVariables = (
      if user.isMainUser then
        {
          NXCORE_DIR = "$HOME/.config/nx/nxcore";
          NXCONFIG_DIR = "$HOME/.config/nx/nxconfig";
        }
      else
        { }
    );

    homeDirectory = user.home;

    stateVersion = variables.state-version;
  };

  programs = {
    home-manager = {
      enable = true;
    };
  };

  nix = {
    settings = {
      http-connections = variables.httpConnections;
      experimental-features = variables.experimental-features;
    };

  };
}
