args@{
  lib,
  pkgs,
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
  buildModules = funcs.computeStandaloneBuildModules { addBaseGroup = user.addBaseGroup; };
  extraContextModules = funcs.collectContextEnabledModules args;
  allModules = funcs.collectAllModulesWithSettings args initialModules (
    lib.recursiveUpdate buildModules extraContextModules
  );

  extraUserModule =
    if (user.extraModulePath or null) != null && builtins.pathExists user.extraModulePath then
      [ (import user.extraModulePath args) ]
    else
      [ ];

  contextModules = funcs.buildContextModules {
    args = args;
    processedModules = allModules;
    buildContext = "home-standalone";
    profiles = [
      {
        profile = user;
        profileType = "home-standalone";
        profileName = user.profileName;
      }
    ];
    specialisations = user.specialisations or { };
    extraUserModule = extraUserModule;
    assertionModules = [
      (import ../../assertions/home/home-standalone.nix (args // { processedModules = allModules; }))
      (import ../../assertions/home/shared.nix (args // { processedModules = allModules; }))
    ];
  };

  nxCli = import ./nx-cli.nix {
    inherit
      lib
      pkgs
      defs
      inputs
      ;
    scope = "standalone";
    deploymentMode = user.deploymentMode or "develop";
  };
in
{ config, options, ... }:
let
  nxDef = nxCli.mkNxDef config.nx.commandline;
in
{
  imports = contextModules.imports;

  specialisation = contextModules.specialisationConfigs;

  home = {
    username = user.username;

    packages =
      (user.additionalPackages or [ ]) ++ lib.optionals nxCli.nxCliEnabled (nxCli.packages nxDef);

    file = lib.optionalAttrs nxCli.nxCliEnabled (nxCli.mkCompletionFiles nxDef config);

    sessionVariables = lib.optionalAttrs nxCli.nxCliEnabled nxCli.sessionVariables;

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
