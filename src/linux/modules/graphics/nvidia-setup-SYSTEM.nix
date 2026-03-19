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
  namespace = "system";

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

  assertions = [
    {
      assertion = self.user.isModuleEnabled "graphics.nvidia-setup";
      message = "Requires linux.graphics.nvidia-setup home module to be enabled for integrated user!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
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
}
