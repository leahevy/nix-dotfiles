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
  rollbackScript = ''
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
      if [ -e /dev/vgmain/root ]; then
        DEVICE_PATH="/dev/vgmain/root"
      elif [ -e /dev/mapper/cryptroot ]; then
        DEVICE_PATH="/dev/mapper/cryptroot"  
      fi
      
      if [ -z "$DEVICE_PATH" ]; then
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Waiting for encrypted device... (attempt $RETRY_COUNT/$MAX_RETRIES)"
        sleep 0.5
      fi
    done

    mkdir -p /mnt-tmp
    ROLLBACK_SUCCESS=1

    if [ -n "$DEVICE_PATH" ] && mount -o subvol=@persist "$DEVICE_PATH" /mnt-tmp 2>/dev/null; then
      mkdir -p /mnt-tmp/var/log/nx/impermanence
      
      {
        echo "=== NixOS Impermanence Rollback Started at $(date) ==="
        set -x
        
        echo -n "Starting impermanence rollback process......."
        
        echo "Device detection phase:"
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
        echo "  - Selected device: $DEVICE_PATH"
        
        if [ -z "$DEVICE_PATH" ]; then
          echo "ERROR: No recognized encrypted root device found for impermanence rollback"
          echo "RESULT: Boot will be aborted - impermanence requires proper device detection"
          echo ""
          echo "Press any key to continue to emergency shell..."
          read -n 1 _
          exit 1
        fi
        
        echo "Persistence mount phase:"
        echo "  - Successfully mounted persistence storage from $DEVICE_PATH"
        echo "  - Log directory created at /persist/var/log/nx/impermanence/"
        
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
{
  name = "impermanence";
  group = "system";
  input = "build";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      config = lib.mkIf (self.host.impermanence or false) {
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
            "/etc/resolv.conf"
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
        boot.initrd.availableKernelModules = lib.mkIf (!config.boot.initrd.systemd.enable) [
          "btrfs"
          "dm_mod"
          "dm_crypt"
        ];
        boot.initrd.extraUtilsCommands = lib.mkIf (!config.boot.initrd.systemd.enable) ''
          copy_bin_and_libs ${pkgs.gnugrep}/bin/grep
          copy_bin_and_libs ${pkgs.gnused}/bin/sed
        '';

        boot.initrd.systemd.services.impermanence-rollback = lib.mkIf config.boot.initrd.systemd.enable {
          description = "NixOS Impermanence Rollback";
          wantedBy = [ "initrd.target" ];
          after = [
            "systemd-cryptsetup@cryptroot.service"
            "systemd-cryptsetup@enc.service"
            "lvm2-activation.service"
            "systemd-udev-settle.service"
            "systemd-hibernate-resume@.service"
            "systemd-hibernate-resume.service"
          ];
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
      };
    };
}
