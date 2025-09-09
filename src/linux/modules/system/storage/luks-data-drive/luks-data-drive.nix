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

  defaults = {
    fsType = "btrfs";
    fsOptions = [
      "compress=zstd"
      "noatime"
    ];
    createXDGDirs = false;
    xdgDirs = [
      "desktop"
      "documents"
      "downloads"
      "music"
      "pictures"
      "public"
      "templates"
      "videos"
      "data"
    ];
    mountpoint = "/data";
    mappedName = "cryptdata";
    keyfileSecretName = "luks-cryptdata-keyfile";
  };

  assertions = [
    {
      assertion = self.settings.uuid != null;
      message = "UUID for crypted device must be set!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      sops.secrets."${self.settings.keyfileSecretName}" = {
        format = "binary";
        sopsFile = helpers.secretsPath "${self.settings.keyfileSecretName}";
        mode = "0400";
        owner = "root";
        group = "root";
      };

      systemd.services."nx-unlock-${self.settings.mappedName}" = {
        description = "Unlock ${self.settings.mappedName}";
        wantedBy = [ "local-fs.target" ];
        after = [
          "dev-disk-by\\x2duuid-${lib.replaceStrings [ "-" ] [ "\\x2d" ] self.settings.uuid}.device"
        ];
        requisite = [
          "dev-disk-by\\x2duuid-${lib.replaceStrings [ "-" ] [ "\\x2d" ] self.settings.uuid}.device"
        ];

        script = ''
          if [ ! -e /dev/mapper/${self.settings.mappedName} ]; then
            ${pkgs.cryptsetup}/bin/cryptsetup open UUID=${self.settings.uuid} ${self.settings.mappedName} \
              --key-file ${config.sops.secrets."${self.settings.keyfileSecretName}".path}
          fi
        '';

        preStop = ''
          ${pkgs.cryptsetup}/bin/cryptsetup close ${self.settings.mappedName} || true
        '';

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      systemd.services."nx-mount-${self.settings.mappedName}" = {
        description = "Mount ${self.settings.mappedName} to ${self.settings.mountpoint}";
        wantedBy = [ "local-fs.target" ];
        after = [ "nx-unlock-${self.settings.mappedName}.service" ];
        requisite = [ "nx-unlock-${self.settings.mappedName}.service" ];

        script =
          let
            fsOptionsStr = lib.concatStringsSep "," self.settings.fsOptions;
          in
          ''
            if ! ${pkgs.util-linux}/bin/mountpoint -q ${self.settings.mountpoint}; then
              mkdir -p ${self.settings.mountpoint}
              ${pkgs.util-linux}/bin/mount -t ${self.settings.fsType} -o ${fsOptionsStr} /dev/mapper/${self.settings.mappedName} ${self.settings.mountpoint}
            fi
          '';

        preStop = ''
          if ${pkgs.util-linux}/bin/mountpoint -q ${self.settings.mountpoint}; then
            ${pkgs.util-linux}/bin/umount ${self.settings.mountpoint} || true
          fi
        '';

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      systemd.services."nx-setup-data-structure" = {
        description = "Setup data directory structure";
        wantedBy = [ "local-fs.target" ];
        after = [ "nx-mount-${self.settings.mappedName}.service" ];
        wants = [ "nx-mount-${self.settings.mappedName}.service" ];

        script =
          let
            userHomePath = self.host.mainUser.home;
            pathParts = lib.filter (x: x != "") (lib.splitString "/" userHomePath);
            createIntermediateDirs = lib.concatMapStrings (
              i:
              let
                partialPath = "/" + lib.concatStringsSep "/" (lib.take i pathParts);
              in
              ''
                mkdir -p "${self.settings.mountpoint}/${self.host.hostname}${partialPath}"
                chown root:root "${self.settings.mountpoint}/${self.host.hostname}${partialPath}"
                chmod 755 "${self.settings.mountpoint}/${self.host.hostname}${partialPath}"
              ''
            ) (lib.range 1 ((lib.length pathParts) - 1));
          in
          ''
            if ! ${pkgs.util-linux}/bin/mountpoint -q ${self.settings.mountpoint}; then
              echo "ERROR: ${self.settings.mountpoint} is not a mountpoint, refusing to create directories"
              exit 1
            fi

            mkdir -p "${self.settings.mountpoint}/${self.host.hostname}"
            chown root:root "${self.settings.mountpoint}/${self.host.hostname}"
            chmod 755 "${self.settings.mountpoint}/${self.host.hostname}"

            ${createIntermediateDirs}

            mkdir -p "${self.settings.mountpoint}/${self.host.hostname}${userHomePath}"
            chown ${self.host.mainUser.username}:${self.host.mainUser.username} "${self.settings.mountpoint}/${self.host.hostname}${userHomePath}"
            chmod 700 "${self.settings.mountpoint}/${self.host.hostname}${userHomePath}"
          '';

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      systemd.services."nx-setup-xdg-dirs" = lib.mkIf self.settings.createXDGDirs {
        description = "Setup XDG directories";
        wantedBy = [ "local-fs.target" ];
        after = [ "nx-setup-data-structure.service" ];
        wants = [ "nx-setup-data-structure.service" ];

        script =
          let
            xdgDirs = self.settings.xdgDirs;
            userHomePath = self.host.mainUser.home;
          in
          ''
            if ! ${pkgs.util-linux}/bin/mountpoint -q ${self.settings.mountpoint}; then
              echo "ERROR: ${self.settings.mountpoint} is not a mountpoint, refusing to create directories"
              exit 1
            fi

            ${lib.concatMapStrings (dir: ''
              mkdir -p "${self.settings.mountpoint}/${self.host.hostname}${userHomePath}/${dir}"
              chown ${self.host.mainUser.username}:${self.host.mainUser.username} "${self.settings.mountpoint}/${self.host.hostname}${userHomePath}/${dir}"
              chmod 755 "${self.settings.mountpoint}/${self.host.hostname}${userHomePath}/${dir}"
            '') xdgDirs}
          '';

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    };
}
