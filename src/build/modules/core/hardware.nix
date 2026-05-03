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
  name = "hardware";

  group = "core";
  input = "build";

  submodules =
    lib.recursiveUpdate
      (
        if
          helpers.resolveFromHost self [ "hardware" "gpu" ] null != null && self.isLinux && self.isPhysical
        then
          { linux.graphics = [ "opengl" ]; }
        else
          { }
      )
      (
        if
          helpers.resolveFromHost self [ "hardware" "gpu" ] null == "nvidia"
          && self.isLinux
          && self.isPhysical
        then
          { linux.graphics = [ "nvidia-setup" ]; }
        else
          { }
      );

  assertions = [
    {
      assertion =
        !(
          self.isPhysical
          && helpers.resolveFromHost self [ "hardware" "board" ] null != null
          && helpers.resolveFromHost self [ "hardware" "cpu" ] null != null
        );
      message = "hardware.cpu must not be set when hardware.board is non-null!";
    }
  ];

  module = {
    system =
      config:
      lib.mkMerge [
        (lib.mkIf (self.host.hardware.cpu == "intel" && self.isPhysical) {
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        })
        (lib.mkIf (self.host.hardware.cpu == "amd" && self.isPhysical) {
          hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        })
      ];
  };
}
