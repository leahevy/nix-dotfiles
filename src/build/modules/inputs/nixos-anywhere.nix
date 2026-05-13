args@{
  lib,
  pkgs,
  pkgs-unstable,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "nixos-anywhere";
  group = "inputs";
  input = "build";

  disableOnVirtual = true;

  module = {
    enabled =
      config:
      let
        currentHostname = helpers.resolveFromHost self [ "hostname" ] "";
        installKey = self.variables.isoManagementSSHKey or null;
        hasInstallKey = installKey != null;

        installHosts =
          if !hasInstallKey then
            { }
          else
            builtins.listToAttrs (
              builtins.filter (x: x != null) (
                lib.mapAttrsToList (
                  profileName: hostCfg:
                  let
                    remoteAddress = hostCfg.remote.address or null;
                    hostname = hostCfg.hostname or "";
                    installPort = if hostCfg.remote.installPort != null then hostCfg.remote.installPort else 22;
                  in
                  if remoteAddress == null || remoteAddress == "" || hostname == currentHostname then
                    null
                  else
                    {
                      name = "nx-deployment---${profileName}---install";
                      value = {
                        user = "root";
                        hostname = remoteAddress;
                        disableHostKeyChecking = true;
                        key = "nx-install";
                      }
                      // lib.optionalAttrs (installPort != null) { port = installPort; };
                    }
                ) (self.nixOSHosts or { })
              )
            );

        deployHosts = builtins.listToAttrs (
          builtins.filter (x: x != null) (
            lib.mapAttrsToList (
              profileName: hostCfg:
              let
                deploySSHPublicKey = hostCfg.remote.deploySSHPublicKey or null;
                hasDeployKey = deploySSHPublicKey != null && deploySSHPublicKey != "";
                deployUser =
                  if hasDeployKey then "nx-deployment" else (hostCfg.mainUser.username or self.user.username);
                remoteDeployPort =
                  if hostCfg.remote.deploymentPort != null then
                    hostCfg.remote.deploymentPort
                  else
                    hostCfg.remote.port;
                remoteAddr = hostCfg.remote.address or null;
                isLoopback =
                  remoteAddr == "localhost"
                  || lib.hasPrefix "127." remoteAddr
                  || remoteAddr == "::1"
                  || remoteAddr == "0:0:0:0:0:0:0:1";
              in
              if (hostCfg.hostname or "") == currentHostname || remoteAddr == null || remoteAddr == "" then
                null
              else
                {
                  name = "nx-deployment---${profileName}---deploy";
                  value = {
                    user = deployUser;
                    hostname = remoteAddr;
                  }
                  // lib.optionalAttrs isLoopback { disableHostKeyChecking = true; }
                  // lib.optionalAttrs hasDeployKey { key = "nx-deploy-${profileName}"; }
                  // lib.optionalAttrs (remoteDeployPort != null) { port = remoteDeployPort; };
                }
            ) (self.nixOSHosts or { })
          )
        );

        deployKeys = builtins.listToAttrs (
          builtins.filter (x: x != null) (
            lib.mapAttrsToList (
              profileName: hostCfg:
              let
                deployKey = hostCfg.remote.deploySSHPublicKey or null;
              in
              if deployKey == null || deployKey == "" then
                null
              else
                {
                  name = "nx-deploy-${profileName}";
                  value = {
                    public = deployKey;
                  };
                }
            ) (self.nixOSHosts or { })
          )
        );
      in
      {
        nx.common.services.ssh.hosts = installHosts // deployHosts;
        nx.common.services.ssh.keys =
          lib.optionalAttrs hasInstallKey {
            "nx-install" = installKey;
          }
          // deployKeys;

        nx.commandline.remote =
          cmds:
          let
            inherit (cmds)
              arg
              option
              optionWith
              commonDeploymentOptions
              ;

            mkRemoteDeploySubcommand =
              {
                description,
                extraOptions ? { },
              }:
              {
                inherit description;
                arguments = [ (arg "profile" "NixOS profile name" "string") ];
                options =
                  commonDeploymentOptions
                  // {
                    build-on-host = option "Build locally on the invoking machine instead of the target";
                    allow-own-profile = option "Allow deploying to the current machine's own profile";
                    allow-localhost = option "Allow localhost/127.0.0.1 as remote address";
                    connect-only = option "Test SSH connectivity without deploying";
                    dry-run = option "Show the final command without connecting or modifying anything";
                    ask = option "Prompt for confirmation before each network or system action";
                  }
                  // extraOptions;
              };
          in
          {
            description = "Remote NixOS deployment";
            group = "switch";
            modes = [
              "develop"
              "local"
            ];
            subcommands = {
              keygen = {
                description = "Generate SOPS age keys for a profile";
                arguments = [ (arg "profile" "NixOS profile name" "string") ];
                options = {
                  shared-key = option "Generate a single age key used for both system and user";
                };
              };
              install = {
                description = "Initial NixOS installation via nixos-anywhere (formats disk!)";
                arguments = [ (arg "profile" "NixOS profile name" "string") ];
                options = commonDeploymentOptions // {
                  age-system-file = optionWith "Use system age key from file path (no sudo)" "system_path" "filepath";
                  age-user-file = optionWith "Use user age key from file path (no sudo)" "user_path" "filepath";
                  age-file = optionWith "Use same age key file for both system+user (no sudo)" "path" "filepath";
                  no-user-age = option "Skip passing a user age key";
                  dangerously-use-host-sops = option "Allow copying host SOPS age key into target via sudo";
                  force = option "Force install even if target already has NixOS";
                  build-on-remote = option "Build on the target rather than locally";
                  allow-own-profile = option "Allow deploying to the current machine's own profile";
                  allow-localhost = option "Allow localhost/127.0.0.1 as remote address";
                  connect-only = option "Test SSH connectivity without deploying";
                  dry-run = option "Show the final command without connecting or modifying anything";
                  ask = option "Prompt for confirmation before each network or system action";
                };
              };
              sync = mkRemoteDeploySubcommand { description = "Deploy configuration to remote NixOS host"; };
              boot = mkRemoteDeploySubcommand { description = "Deploy to remote bootloader without switching"; };
              test = mkRemoteDeploySubcommand {
                description = "Activate configuration remotely without changing boot default";
              };
            };
          };
      };

    home = config: {
      home.packages = [
        self.inputs.nixos-anywhere.packages.${pkgs.system}.default
      ];
      home.persistence."${self.persist}".directories = [
        ".local/share/nx/deploy-keys"
      ];
    };
  };
}
