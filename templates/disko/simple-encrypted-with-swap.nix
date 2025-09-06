{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              name = "boot";
              size = "8G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };
            swap = {
              name = "swap";
              size = "8%";
              content = {
                type = "swap";
              };
            };
            root = {
              name = "root";
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "filesystem";
                  format = "btrfs";
                  mountpoint = "/";
                  mountOptions = [ "subvol=@" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
