{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/mmcblk0";
        content = {
          type = "gpt";
          partitions = {
            firmware = {
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/firmware";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
              };
            };

            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings = {
                  allowDiscards = false;
                  keyFile = null;
                };
                content = {
                  type = "lvm_pv";
                  vg = "vgmain";
                };
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      vgmain = {
        type = "lvm_vg";
        lvs = {
          swap = {
            size = "4G";
            content = {
              type = "swap";
              resumeDevice = false;
            };
          };

          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                "@root-empty" = {
                  mountpoint = null;
                };

                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
              mountpoint = null;
            };
          };
        };
      };
    };
  };
}
