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
  name = "nvidia-setup";

  group = "graphics";
  input = "linux";

  unfree = [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-persistenced"
  ];

  settings = {
    withPowerManagement = true;
    disableGspFirmware = false;
    disableDisplayAudio = true;
  };

  on = {
    linux.home = config: {
      home.persistence."${self.persist.home}" = {
        directories = [
          ".cache/nvidia"
        ];
      };
    };

    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          string = "nvidia.*EDID checksum is invalid";
          kernel = true;
        }
        {
          string = "nvidia.*invalid EDID header";
          kernel = true;
        }
        {
          string = "nvidia-modeset:.*Unable to read EDID for display device.*";
          kernel = true;
        }
        {
          string = "nvidia: module license 'NVIDIA' taints kernel";
          kernel = true;
        }
        {
          string = "nvidia: module license taints kernel";
          kernel = true;
        }
        {
          string = "Disabling lock debugging due to kernel taint";
          kernel = true;
        }
        {
          string = "NVRM: loading NVIDIA UNIX x86_64 Kernel Module";
          kernel = true;
        }
        {
          string = "nvidia_uvm: module uses symbols.*from proprietary module nvidia, inheriting taint";
          kernel = true;
        }
        {
          string = "NVRM: GPU at PCI:.*: GPU-.*";
          kernel = true;
        }
        {
          string = "NVRM: Xid \\(PCI:.*\\):.*";
          kernel = true;
        }
        {
          string = "Failed to allocate NVKMS memory for GEM object";
          kernel = true;
        }
      ];
    };

    linux.system = config: {
      hardware.nvidia = {
        powerManagement = lib.mkIf self.settings.withPowerManagement {
          enable = true;
          finegrained = false;
        };
        nvidiaPersistenced = self.settings.withPowerManagement;
      };

      hardware.graphics = {
        extraPackages = with pkgs; [
          nvidia-vaapi-driver
        ];
      };

      boot.kernelParams = lib.optionals self.settings.disableGspFirmware [
        "nvidia.NVreg_EnableGpuFirmware=0"
      ];

      services.udev.extraRules = lib.optionalString self.settings.disableDisplayAudio ''
        ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{remove}="1"
      '';
    };
  };
}
