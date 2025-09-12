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
  assertions = [
    {
      assertion = self.user.isHostModuleEnabledByName "linux.storage.luks-data-drive";
      message = "linux/storage/luks-data-drive home-manager module requires system module to be enabled: linux/storage/luks-data-drive";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      systemd.user.services.nx-luks-data-drive-ready = {
        Unit = {
          Description = "Wait for LUKS data drive structure to be available";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart =
            let
              mountPoint = (self.user.getHostConfigForModuleByName "linux.storage.luks-data-drive").mountpoint;
              dataPath = "${mountPoint}/${self.host.hostname}${self.user.home}";
              waitScript = pkgs.writeShellScript "wait-for-luks-data" ''
                echo "Waiting for LUKS data structure at ${dataPath}..."
                timeout=60
                elapsed=0
                while [ ! -d "${dataPath}" ] && [ $elapsed -lt $timeout ]; do
                  ${pkgs.coreutils}/bin/sleep 1
                  elapsed=$((elapsed + 1))
                done
                if [ ! -d "${dataPath}" ]; then
                  echo "ERROR: LUKS data structure not available after $timeout seconds"
                  exit 1
                fi
                echo "LUKS data structure is available at ${dataPath}"
              '';
            in
            "${waitScript}";
        };
      };
    };
}
