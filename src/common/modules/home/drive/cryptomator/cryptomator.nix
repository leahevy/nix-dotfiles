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
  name = "cryptomator";
  group = "drive";
  input = "common";
  namespace = "home";

  settings = {
    vaults = { };
    autoMount = true;
  };

  configuration =
    context@{ config, options, ... }:
    let
      hasVaults = self.settings.vaults != { };
      vaultNames = lib.attrNames self.settings.vaults;
      rcloneEnabled = self.isModuleEnabled "drive.rclone";
      luksDataDriveEnabled = self.isLinux && self.linux.isModuleEnabled "storage.luks-data-drive";

      vaultSecrets = lib.foldl' (
        acc: name:
        acc
        // {
          "cryptomator-${name}-pass" = {
            format = "binary";
            sopsFile = self.config.secretsPath "cryptomator-${name}-pass";
            mode = "0400";
          };
        }
      ) { } vaultNames;

      vaultServices = lib.foldl' (
        acc: name:
        let
          cfg = self.settings.vaults.${name};
          vaultPath =
            if lib.hasPrefix "/" cfg.vaultPath then
              cfg.vaultPath
            else
              "${config.home.homeDirectory}/${cfg.vaultPath}";
          mountPath =
            if lib.hasPrefix "/" cfg.mountPath then
              cfg.mountPath
            else
              "${config.home.homeDirectory}/${cfg.mountPath}";
          passwordPath = config.sops.secrets."cryptomator-${name}-pass".path;
        in
        acc
        // {
          "cryptomator-mount-${name}" = {
            Unit = {
              Description = "Mount Cryptomator vault: ${name}";
              After = [
                "sops-nix.service"
              ]
              ++ lib.optional luksDataDriveEnabled "nx-luks-data-drive-ready.service"
              ++ lib.optional (rcloneEnabled && (cfg.afterRclone or true)) "rclone-bisync.service";
              Requires = lib.optional luksDataDriveEnabled "nx-luks-data-drive-ready.service";
              StartLimitIntervalSec = 300;
              StartLimitBurst = 3;
            };
            Service = {
              Type = "simple";
              WorkingDirectory = "/tmp";
              Environment = [
                "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus"
              ];
              ExecStart = pkgs.writeShellScript "mount-cryptomator-${name}" ''
                set -euo pipefail

                if [[ ! -c /dev/fuse ]]; then
                  echo "ERROR: /dev/fuse not available - FUSE kernel module may not be loaded"
                  exit 1
                fi

                if [[ ! -d "${vaultPath}" ]]; then
                  echo "ERROR: Vault directory does not exist: ${vaultPath}"
                  exit 1
                fi

                if [[ ! -r "${vaultPath}/masterkey.cryptomator" ]]; then
                  echo "ERROR: Cannot read masterkey.cryptomator in vault: ${vaultPath}"
                  exit 1
                fi

                if [[ ! -r "${passwordPath}" ]]; then
                  echo "ERROR: Password file does not exist or is not readable: ${passwordPath}"
                  exit 1
                fi

                if ${pkgs.util-linux}/bin/mountpoint -q "${mountPath}" 2>/dev/null; then
                  echo "ERROR: Mount point already mounted: ${mountPath}"
                  exit 1
                fi

                ${pkgs.coreutils}/bin/mkdir -p "${mountPath}"

                ${pkgs.coreutils}/bin/cat "${passwordPath}" | \
                  ${pkgs-unstable.cryptomator-cli}/bin/cryptomator-cli unlock \
                    --password:stdin \
                    --mounter=org.cryptomator.frontend.fuse.mount.LinuxFuseMountProvider \
                    --mountPoint="${mountPath}" \
                    "${vaultPath}"
              '';
              ExecStopPost = "-${pkgs.coreutils}/bin/rmdir ${mountPath}";
            };
            Install.WantedBy = lib.optional (
              (cfg.autoMount or true) && self.settings.autoMount
            ) "graphical-session.target";
          };
        }
      ) { } vaultNames;

    in
    lib.mkIf hasVaults {
      home.packages = [
        pkgs-unstable.cryptomator-cli
        pkgs.fuse3
      ];

      sops.secrets = vaultSecrets;

      systemd.user.services = vaultServices;
    };
}
