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
let
  dropTrailingEmptyLines =
    lines:
    if lines == [ ] then
      [ ]
    else if lib.last lines == "" then
      dropTrailingEmptyLines (lib.init lines)
    else
      lines;

  makeIndentTail =
    level: text:
    let
      prefix = builtins.concatStringsSep "" (lib.replicate (level * 2) " ");
      lines = dropTrailingEmptyLines (lib.splitString "\n" text);
      first = if lines == [ ] then "" else builtins.head lines;
      rest = if lines == [ ] then [ ] else builtins.tail lines;
      indentedRest = builtins.map (line: if line == "" then "" else "${prefix}${line}") rest;
    in
    builtins.concatStringsSep "\n" ([ first ] ++ indentedRest);

  stripIndent =
    text:
    let
      lines = lib.splitString "\n" text;
      nonEmptyLines = builtins.filter (line: line != "") lines;
      leadingSpacesLens = builtins.map (
        line:
        let
          m = builtins.match "^( *)" line;
        in
        if m == null then 0 else builtins.stringLength (builtins.elemAt m 0)
      ) nonEmptyLines;
      minLeadingSpaces =
        if nonEmptyLines == [ ] then
          0
        else
          lib.foldl' (acc: n: if n < acc then n else acc) 999999 leadingSpacesLens;
      dedentedLines = builtins.map (
        line:
        if line == "" then
          ""
        else
          builtins.substring minLeadingSpaces (builtins.stringLength line - minLeadingSpaces) line
      ) lines;
    in
    builtins.concatStringsSep "\n" dedentedLines;

  mkImpermanenceRollbackScript =
    {
      withLuksOrLvm ? true,
      candidateDevices ? [ ],
    }:
    let
      waitForDeviceMessage = if withLuksOrLvm then "encrypted device" else "persistence device";

      candidateDevicesString = builtins.concatStringsSep " " (
        builtins.map lib.escapeShellArg candidateDevices
      );

      deviceDetectLoop =
        if withLuksOrLvm then
          ''
            if [ -e /dev/vgmain/root ]; then
              DEVICE_PATH="/dev/vgmain/root"
            elif [ -e /dev/mapper/cryptroot ]; then
              DEVICE_PATH="/dev/mapper/cryptroot"
            fi
          ''
        else
          ''
            mkdir -p /mnt-tmp
            for dev in ${candidateDevicesString}; do
              if mount -o subvol=@persist "$dev" /mnt-tmp 2>/dev/null; then
                umount /mnt-tmp 2>/dev/null || true
                DEVICE_PATH="$dev"
                break
              fi
            done

            if [ -z "$DEVICE_PATH" ]; then
            for dev in $(blkid -t TYPE=btrfs -o device 2>/dev/null); do
              if mount -o subvol=@persist "$dev" /mnt-tmp 2>/dev/null; then
                umount /mnt-tmp 2>/dev/null || true
                DEVICE_PATH="$dev"
                break
              fi
            done
            fi
          '';

      deviceDetectionLog =
        if withLuksOrLvm then
          ''
            if [ -e /dev/vgmain/root ]; then
              echo "  - Detected LVM setup: /dev/vgmain/root"
            elif [ -e /dev/mapper/cryptroot ]; then
              echo "  - Detected direct LUKS setup: /dev/mapper/cryptroot"
            else
              echo "  - Available /dev/mapper devices:"
              ls -la /dev/mapper/ 2>/dev/null || echo "    (none found)"
              echo "  - Available /dev/vgmain devices:"
              ls -la /dev/vgmain/ 2>/dev/null || echo "    (none found)"
            fi
          ''
        else
          ''
            echo "  - Detected direct btrfs setup (no LUKS/LVM)"
          '';

      noDeviceError =
        if withLuksOrLvm then
          ''
            echo "ERROR: No recognized encrypted root device found for impermanence rollback"
          ''
        else
          ''
            echo "ERROR: No recognized root device found for impermanence rollback"
          '';

      rawScript = ''
        if [ -f /sys/power/resume ] && [ "$(cat /sys/power/resume)" != "0:0" ]; then
          echo "Hibernation resume device configured - checking state..."
          if [ -f /run/systemd/resume-attempted ] || [ -f /sys/power/image_exists ]; then
            echo "Hibernation resume in progress - skipping impermanence rollback"
            exit 0
          fi
        fi

        if grep -q 'resume=' /proc/cmdline; then
          resume_device=$(cat /proc/cmdline | sed -n 's/.*resume=\([^ ]*\).*/\1/p')
          if [ -n "$resume_device" ] && [ -e "$resume_device" ]; then
            echo "Resume device specified: $resume_device - verifying..."
            sleep 1
            if [ -f /run/systemd/resume-attempted ]; then
              echo "Hibernation resume attempted - skipping rollback"
              exit 0
            fi
          fi
        fi

        printf "\033[1;37mAttempting to rollback system due to impermanence...\033[0m"

        DEVICE_PATH=""
        MAX_RETRIES=10
        RETRY_COUNT=0

        while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ -z "$DEVICE_PATH" ]; do
          ${makeIndentTail 1 deviceDetectLoop}

          if [ -z "$DEVICE_PATH" ]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "Waiting for ${waitForDeviceMessage}... (attempt $RETRY_COUNT/$MAX_RETRIES)"
            sleep 0.5
          fi
        done

        ${lib.optionalString withLuksOrLvm "mkdir -p /mnt-tmp"}
        ROLLBACK_SUCCESS=1

        if [ -n "$DEVICE_PATH" ] && mount -o subvol=@persist "$DEVICE_PATH" /mnt-tmp 2>/dev/null; then
          mkdir -p /mnt-tmp/var/log/nx/impermanence

          {
            echo "=== NixOS Impermanence Rollback Started at $(date) ==="
            set -x

            echo -n "Starting impermanence rollback process......."

            echo "Device detection phase:"
            ${makeIndentTail 2 deviceDetectionLog}
            echo "  - Selected device: $DEVICE_PATH"

            if [ -z "$DEVICE_PATH" ]; then
              ${makeIndentTail 3 noDeviceError}
              echo "RESULT: Boot will be aborted - impermanence requires proper device detection"
              echo ""
              echo "Press any key to continue to emergency shell..."
              read -n 1 _
              exit 1
            fi

            echo "Persistence mount phase:"
            echo "  - Successfully mounted persistence storage from $DEVICE_PATH"
            echo "  - Log directory created at ${self.persist}/var/log/nx/impermanence/"

            echo "Root filesystem mount phase:"
            mkdir -p /mnt
            if ! mount -o subvolid=5 "$DEVICE_PATH" /mnt; then
              echo "ERROR: Failed to mount root btrfs filesystem from $DEVICE_PATH"
              echo "RESULT: Boot will be aborted - cannot access root filesystem"
              echo
              echo "Press any key to continue to emergency shell..."
              read -n 1 _
              exit 1
            fi
            echo "  - Successfully mounted root btrfs filesystem"

            echo "Subvolume verification phase:"
            echo "  - Checking for required @root-empty snapshot..."
            if [ ! -e /mnt/@root-empty ]; then
              echo "ERROR: No @root-empty snapshot found - impermanence not properly initialized"
              echo "  - This indicates bootstrap process was incomplete"
              echo "  - Run bootstrap scripts to create initial @root-empty snapshot"
              echo "  - Available subvolumes:"
              btrfs subvolume list /mnt 2>/dev/null || echo "    (failed to list subvolumes)"
              echo
              echo "RESULT: Boot will be aborted - missing required snapshot"
              echo
              echo "Press any key to continue to emergency shell..."
              read -n 1 _
              exit 1
            fi
            echo "  - Found required @root-empty snapshot"

            echo "Root cleanup phase:"
            if [ -e /mnt/@root ]; then
              echo "  - Found existing @root subvolume (dirty state from previous boot)"

              echo "  - Unmounting any filesystems in @root..."
              umount -R /mnt/@root 2>/dev/null || true

              nested_subvols=$(btrfs subvolume list -o /mnt/@root 2>/dev/null | cut -f9 -d' ' | sort -r || true)
              if [ -n "$nested_subvols" ]; then
                echo "  - Deleting nested subvolumes first..."
                echo "$nested_subvols" | while read -r subvol; do
                  if [ -n "$subvol" ]; then
                    if ! btrfs subvolume delete "/mnt/$subvol"; then
                      echo "ERROR: Failed to delete nested subvolume $subvol"
                      echo "  - Nested subvolumes:"
                      btrfs subvolume list -o /mnt/@root 2>/dev/null || echo "    (none found)"
                      echo "  - Available subvolumes:"
                      btrfs subvolume list /mnt 2>/dev/null || echo "    (none found)"
                      echo "RESULT: Boot will be aborted - cannot clean dirty state"
                      echo
                      echo "Press any key to continue to emergency shell..."
                      read -n 1 _
                      exit 1
                    fi
                  fi
                done
              fi

              echo "  - Deleting dirty @root subvolume..."
              if ! btrfs subvolume delete /mnt/@root; then
                echo "ERROR: Failed to delete dirty @root subvolume"
                echo "  - Remaining nested subvolumes:"
                btrfs subvolume list -o /mnt/@root 2>/dev/null || echo "    (none found)"
                echo "  - Available subvolumes:"
                btrfs subvolume list /mnt 2>/dev/null || echo "    (all subvolumes listed above)"
                echo "RESULT: Boot will be aborted - cannot clean dirty state"
                echo
                echo "Press any key to continue to emergency shell..."
                read -n 1 _
                exit 1
              fi
            else
              echo "  - No existing @root subvolume found (clean boot or first boot)"
            fi

            echo "Root restoration phase:"
            if ! btrfs subvolume snapshot /mnt/@root-empty /mnt/@root; then
              echo "ERROR: Failed to restore @root from @root-empty snapshot"
              echo "  - Available subvolumes:"
              btrfs subvolume list /mnt 2>/dev/null || echo "    (none found)"
              echo "RESULT: Boot will be aborted - cannot restore clean state"
              echo
              echo "Press any key to continue to emergency shell..."
              read -n 1 _
              exit 1
            fi

            echo "Cleanup phase:"
            umount /mnt 2>/dev/null || true

            set +x
            echo "=== Impermanence Rollback Completed Successfully at $(date) ==="
          } > /mnt-tmp/var/log/nx/impermanence/rollback.log 2>&1
          ROLLBACK_SUCCESS=$?

          chmod 644 /mnt-tmp/var/log/nx/impermanence/rollback.log 2>/dev/null || true
          umount /mnt-tmp 2>/dev/null || echo "WARNING: Failed to unmount persistence storage"

          if [ $ROLLBACK_SUCCESS -eq 0 ]; then
            printf "\033[1;32msuccess\033[0m\n"
          else
            echo
            printf "\033[1;31mCRITICAL: Impermanence rollback failed\033[0m\n"
            if [ -f /mnt-tmp/var/log/nx/impermanence/rollback.log ]; then
              echo "=== Rollback Log Details ==="
              cat /mnt-tmp/var/log/nx/impermanence/rollback.log
              echo "=== End Rollback Log ==="
            fi
            echo
            echo "Press any key to continue to emergency shell..."
            read -n 1 _
            exit 1
          fi
        else
          echo
          printf "\033[1;31mCRITICAL ERROR: Failed to mount persistence storage for impermanence rollback\033[0m\n"
          echo "  - Device path: $DEVICE_PATH"
          echo "  - Cannot log rollback process or perform rollback"
          echo
          echo "RESULT: Boot will be aborted - impermanence requires persistent storage access"
          echo
          echo "Press any key to continue to emergency shell..."
          read -n 1 _
          exit 1
        fi

        rmdir /mnt-tmp 2>/dev/null || true
        rmdir /mnt 2>/dev/null || true
      '';
    in
    stripIndent rawScript;
in
{
  name = "impermanence";
  group = "system";
  input = "build";

  module = {
    enabled = config: {
      nx.commandline.impermanence =
        cmds:
        let
          inherit (cmds) option optionWith optionRepeatable;
        in
        {
          description = "Manage ephemeral root filesystems";
          group = "switch";
          scope = "integrated";
          subcommands = {
            check = {
              description = "List files/directories in ephemeral root";
              options = {
                home = option "Show only paths under /home";
                system = option "Show only system paths";
                filter = optionRepeatable "Filter results by keyword" "keyword" "string";
              };
            };
            diff = {
              description = "Compare historical impermanence check logs";
              options = {
                range = optionWith "Compare with Nth previous log" "range" "int";
                home = option "Compare only home check logs";
                system = option "Compare only system check logs";
              };
            };
            logs = {
              description = "Show impermanence rollback logs";
            };
          };
        };
    };
    system =
      config:
      let
        diskoDevices = config.disko.devices or { };
        usesLuks = (config.boot.initrd.luks.devices or { }) != { };
        usesLvm = (diskoDevices.lvm_vg or { }) != { };
        withLuksOrLvm = usesLuks || usesLvm;

        persistFsDevice = (config.fileSystems.${self.persist} or { }).device or null;

        candidateDevices = builtins.filter (d: d != null && d != "") [
          persistFsDevice
        ];

        rollbackScript = mkImpermanenceRollbackScript { inherit withLuksOrLvm candidateDevices; };

        extraUtilsBlkid = lib.optionalString (
          !withLuksOrLvm
        ) "copy_bin_and_libs ${pkgs.util-linux}/bin/blkid";

        luksDeviceNames = builtins.attrNames (config.boot.initrd.luks.devices or { });

        systemdAfterCryptsetup = lib.optionals usesLuks (
          builtins.map (name: "systemd-cryptsetup@${name}.service") luksDeviceNames
        );

        systemdAfterLvm = lib.optionals usesLvm [ "lvm2-activation.service" ];

        impermanenceAfterUnits =
          systemdAfterCryptsetup
          ++ systemdAfterLvm
          ++ [
            "systemd-udev-settle.service"
            "systemd-hibernate-resume@.service"
            "systemd-hibernate-resume.service"
          ];

        username = self.host.mainUser.username;
        userUid = toString config.users.users.${username}.uid;
        userGid = toString config.users.groups.${config.users.users.${username}.group}.gid;

        normalizeFile = f: if builtins.isString f then f else f.file;
        escapeUnitPath = path: lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" path);

        sysPersistFiles = map normalizeFile (config.environment.persistence.${self.persist}.files or [ ]);
        homePersistFiles = lib.optionals (!self.user.isStandalone) (
          map normalizeFile (
            (config.home-manager.users.${username}.home.persistence.${self.persist} or { }).files or [ ]
          )
        );

        sysPersistPaths = map (f: "${self.persist}${f}") sysPersistFiles;
        homePersistPaths = map (f: "${self.persist}${self.user.home}/${f}") homePersistFiles;
        allPersistPaths = sysPersistPaths ++ homePersistPaths;

        persistUnits = map (p: "persist-${escapeUnitPath p}.service") allPersistPaths;

        userHomePersist = "${self.persist}${self.user.home}";

        dirsOfPath =
          base: filePath:
          let
            dirPath = builtins.dirOf filePath;
            relPath = lib.removePrefix "${base}/" dirPath;
            components = lib.filter (c: c != "") (lib.splitString "/" relPath);
            buildPaths =
              prefix: remaining:
              if remaining == [ ] then
                [ ]
              else
                let
                  next = "${prefix}/${builtins.head remaining}";
                in
                [ next ] ++ buildPaths next (builtins.tail remaining);
          in
          if dirPath == base then [ ] else buildPaths base components;

        mkSysDirBlock =
          dir:
          let
            perm = if dir == "${self.persist}/root" then "750" else "755";
          in
          ''
            if [ ! -d ${lib.escapeShellArg dir} ]; then
              ${pkgs.coreutils}/bin/echo "Create directory ${dir}"
              ${pkgs.coreutils}/bin/mkdir ${lib.escapeShellArg dir} || true
              ${pkgs.coreutils}/bin/chmod ${perm} ${lib.escapeShellArg dir} || true
              SYS_DIR_COUNT=$((SYS_DIR_COUNT + 1))
            fi'';

        mkHomeDirBlock =
          dir:
          let
            perm = if dir == userHomePersist then "700" else "755";
          in
          ''
            if [ ! -d ${lib.escapeShellArg dir} ]; then
              ${pkgs.coreutils}/bin/echo "Create directory ${dir}"
              ${pkgs.coreutils}/bin/mkdir ${lib.escapeShellArg dir} || true
              ${pkgs.coreutils}/bin/chmod ${perm} ${lib.escapeShellArg dir} || true
              ${pkgs.coreutils}/bin/chown ${userUid}:${userGid} ${lib.escapeShellArg dir} || true
              HOME_DIR_COUNT=$((HOME_DIR_COUNT + 1))
            fi'';

        mkDirBlocksForPath =
          p:
          let
            dirs = dirsOfPath self.persist p;
            sysDirs = lib.filter (d: !lib.hasPrefix userHomePersist d) dirs;
            homeDirs = lib.filter (d: lib.hasPrefix userHomePersist d) dirs;
          in
          lib.concatStringsSep "\n" (map mkSysDirBlock sysDirs ++ map mkHomeDirBlock homeDirs);

        touchFilesScript = pkgs.writeShellScript "impermanence-touch-files" ''
          if [ ! -d ${lib.escapeShellArg self.persist} ]; then
            ${pkgs.coreutils}/bin/echo "Persist directory ${self.persist} not found, skipping"
            exit 0
          fi
          SYS_COUNT=0
          HOME_COUNT=0
          SYS_DIR_COUNT=0
          HOME_DIR_COUNT=0
          ${lib.concatMapStringsSep "\n" (p: ''
            ${mkDirBlocksForPath p}
            if [ ! -e ${lib.escapeShellArg p} ]; then
              ${pkgs.coreutils}/bin/echo "Touch file ${p}"
              ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg p} || true
              ${pkgs.coreutils}/bin/chmod 644 ${lib.escapeShellArg p} || true
              SYS_COUNT=$((SYS_COUNT + 1))
            fi'') sysPersistPaths}
          ${lib.concatMapStringsSep "\n" (p: ''
            ${mkDirBlocksForPath p}
            if [ ! -e ${lib.escapeShellArg p} ]; then
              ${pkgs.coreutils}/bin/echo "Touch file ${p}"
              ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg p} || true
              ${pkgs.coreutils}/bin/chmod 644 ${lib.escapeShellArg p} || true
              ${pkgs.coreutils}/bin/chown ${userUid}:${userGid} ${lib.escapeShellArg p} || true
              HOME_COUNT=$((HOME_COUNT + 1))
            fi'') homePersistPaths}
          ${pkgs.coreutils}/bin/echo "Touched $SYS_COUNT system and $HOME_COUNT user files, created $SYS_DIR_COUNT system and $HOME_DIR_COUNT user dirs"
        '';
      in
      lib.mkIf (self.host.impermanence or false) {
        assertions = [
          {
            assertion =
              usesLvm
              -> ((diskoDevices.lvm_vg or { }) ? vgmain && ((diskoDevices.lvm_vg.vgmain.lvs or { }) ? root));
            message = "Impermanence rollback expects an LVM root at /dev/vgmain/root but disko does not define lvm_vg.vgmain.lvs.root!";
          }
          {
            assertion = (usesLuks && !usesLvm) -> ((config.boot.initrd.luks.devices or { }) ? cryptroot);
            message = "Impermanence rollback expects a LUKS root mapper named cryptroot when LVM is not used but boot.initrd.luks.devices.cryptroot is not defined!";
          }
          {
            assertion =
              (config.fileSystems.${self.persist} or { }) ? options
              && lib.elem "subvol=@persist" (config.fileSystems.${self.persist}.options or [ ]);
            message = "Impermanence requires fileSystems.${self.persist}.options to include subvol=@persist!";
          }
          {
            assertion = withLuksOrLvm || (candidateDevices != [ ]);
            message = "Impermanence rollback requires fileSystems.${self.persist}.device to be set for non-LUKS/LVM setups!";
          }
        ];

        environment.systemPackages = [ pkgs.rsync ];

        environment.persistence.${self.persist} = {
          hideMounts = true;

          directories = [
            "/var/lib/nixos"
            "/var/lib/systemd"
            "/var/lib/sops-nix"
            "/var/log"
            "/var/spool"
            "/etc/NetworkManager/system-connections"
            "/etc/sops"
            "/var/lib/bluetooth"
            "/etc/ssh"
            "/root/.ssh"
          ];

          files = [
            "/etc/machine-id"
            "/etc/NIXOS"
            "/etc/IMPERMANENCE"
          ];
        };

        sops.age.keyFile = lib.mkDefault "${self.persist}/etc/sops/age/keys.txt";

        fileSystems.${self.persist} = {
          neededForBoot = true;
        };

        boot.initrd.systemd.enable = lib.mkDefault false;

        boot.initrd.postDeviceCommands = lib.mkIf (!config.boot.initrd.systemd.enable) (
          lib.mkAfter rollbackScript
        );
        boot.initrd.extraUtilsCommands = lib.mkIf (!config.boot.initrd.systemd.enable) ''
          copy_bin_and_libs ${pkgs.gnugrep}/bin/grep
          copy_bin_and_libs ${pkgs.gnused}/bin/sed
          ${extraUtilsBlkid}
        '';

        boot.initrd.systemd.services.impermanence-rollback = lib.mkIf config.boot.initrd.systemd.enable {
          description = "NixOS Impermanence Rollback";
          wantedBy = [ "initrd.target" ];
          after = impermanenceAfterUnits;
          before = [ "sysroot.mount" ];

          unitConfig = {
            DefaultDependencies = "no";
            ConditionPathExists = "!/run/systemd/resume-attempted";
          };

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = "yes";
            TimeoutSec = "360s";
          };

          script = rollbackScript;
        };

        boot.initrd.systemd.initrdBin = lib.mkIf config.boot.initrd.systemd.enable (
          with pkgs;
          [
            btrfs-progs
            coreutils
            util-linux
            gnugrep
            gnused
          ]
        );

        sops.age.sshKeyPaths = lib.mkDefault [
          "${self.persist}/etc/ssh/ssh_host_ed25519_key"
        ];

        programs.fuse.userAllowOther = true;

        environment.etc."nx/impermanence-rollback-script" = {
          text = rollbackScript;
          mode = "0444";
          user = "root";
          group = "root";
        };

        systemd.services.impermanence-touch-files = lib.mkIf (allPersistPaths != [ ]) {
          description = "Touch impermanence files before bind mounts";
          wantedBy = [ "local-fs.target" ];
          unitConfig = {
            DefaultDependencies = false;
            Before = [ "local-fs.target" ] ++ persistUnits;
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = touchFilesScript;
          };
        };
      };

    home =
      config:
      lib.mkIf (!self.user.isStandalone && self.isLinux && (self.host.impermanence or false)) {
        home.persistence."${self.persist}" = {
          directories = [
            ".config/nx"
            ".config/nix"
            ".config/sops"
            ".cache/nix"
            ".local/logs/nx"
          ];

          files = [
            ".bash_history"
          ];
        };
      };
  };
}
