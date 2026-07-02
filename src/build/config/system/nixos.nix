args@{
  lib,
  pkgs,
  inputs,
  host,
  users,
  funcs,
  helpers,
  defs,
  variables,
  processedModules,
  ...
}:

let
  allModules = processedModules;

  systemArgs = args // {
    user = host.mainUser;
    processedModules = allModules;
  };

  contextModules = funcs.buildContextModules {
    args = systemArgs;
    processedModules = allModules;
    buildContext = "system";
    profiles = [
      {
        profile = host;
        profileType = "nixos";
        profileName = host.profileName;
      }
      {
        profile = host.mainUser;
        profileType = "home-integrated";
        profileName = host.mainUser.profileName;
      }
    ];
    specialisations = host.specialisations;
    assertionModules = [
      (import ../../assertions/system/nixos.nix (systemArgs // { processedModules = allModules; }))
    ];
  };
in
{ config, options, ... }:
{
  imports = contextModules.imports;

  config = {
    specialisation = contextModules.specialisationConfigs;

    environment = {
      systemPackages = host.additionalPackages or [ ];
    };

    system.stateVersion =
      if host.stateVersion != null then host.stateVersion else variables.state-version;

    nixpkgs.hostPlatform = lib.mkIf ((host.hardware.board or null) != "pi5") host.architecture;

    nix = {
      settings =
        let
          deploymentUsers =
            if
              (host.deploymentMode == "managed" || host.deploymentMode == "server")
              && host.remote.address != null
              && host.remote.deploySSHPublicKey != null
            then
              [ "nx-deployment" ]
            else
              [ ];
          users = [ host.mainUser.username ] ++ deploymentUsers;
        in
        {
          experimental-features = variables.experimental-features;
          trusted-users = lib.mkForce [ ];
          allowed-users = lib.mkForce users;
          http-connections = variables.httpConnections;
          max-substitution-jobs = variables.maxSubstitutionJobs;
          connect-timeout = variables.connectTimeout;
          stalled-download-timeout = variables.stalledDownloadTimeout;
          download-speed = variables.downloadSpeedMbits * 1000000 / 8 / 1024;
          http2 = false;
          keep-outputs = true;
          keep-derivations = true;
          allow-import-from-derivation = false;
          auto-optimise-store = true;
        };
    };
  };
}
