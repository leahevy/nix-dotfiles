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
          (self ? host && self.host.hardware.gpu != null && self.isLinux && !(self.host.isVM or false))
        then
          { linux.graphics = [ "opengl" ]; }
        else
          { }
      )
      (
        if
          (self ? host && self.host.hardware.gpu == "nvidia" && self.isLinux && !(self.host.isVM or false))
        then
          { linux.graphics = [ "nvidia-setup" ]; }
        else
          { }
      );

  assertions = [
    {
      assertion =
        !(
          self ? host
          && !(self.host.isVM or false)
          && self.host.hardware.board != null
          && self.host.hardware.cpu != null
        );
      message = "hardware.cpu must not be set when hardware.board is non-null!";
    }
  ];

  module = {
    system =
      config:
      lib.mkMerge [
        (lib.mkIf (self.host.hardware.cpu == "intel" && !(self.host.isVM or false)) {
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        })
        (lib.mkIf (self.host.hardware.cpu == "amd" && !(self.host.isVM or false)) {
          hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        })
      ];
  };
}
