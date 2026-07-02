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

  nxCli = import ./nx-cli.nix {
    inherit
      lib
      pkgs
      defs
      inputs
      ;
    scope = "integrated";
    deploymentMode = host.deploymentMode or "develop";
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
      (user.additionalPackages or [ ])
      ++ (if user.isMainUser && nxCli.nxCliEnabled then nxCli.packages nxDef else [ ]);

    file = lib.optionalAttrs (user.isMainUser && nxCli.nxCliEnabled) (
      nxCli.mkCompletionFiles nxDef config
    );

    sessionVariables = (if user.isMainUser && nxCli.nxCliEnabled then nxCli.sessionVariables else { });

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
