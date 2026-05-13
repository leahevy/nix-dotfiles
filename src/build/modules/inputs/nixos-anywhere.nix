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
      };

    home = config: {
      home.packages = [
        self.inputs.nixos-anywhere.packages.${pkgs.system}.default
      ];
    };
  };
}
