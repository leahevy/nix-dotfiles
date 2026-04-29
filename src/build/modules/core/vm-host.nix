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
  name = "vm-host";

  group = "core";
  input = "build";

  disableOnVM = true;

  module = {
    system =
      config:
      lib.mkIf self.host.settings.system.virtualisation.enableKVM {
        boot.kernelModules =
          lib.optional (self.host.hardware.cpu == "intel") "kvm-intel"
          ++ lib.optional (self.host.hardware.cpu == "amd") "kvm-amd";

        environment.systemPackages = with pkgs; [
          qemu
          OVMF
        ];
      };
    home =
      { config, ... }:
      {
        home.persistence."${self.persist}".directories = [
          ".cache/nx/vms"
        ];
      };
  };
}
