{
  config,
  pkgs,
  lib,
  variables,
  helpers,
  nx-repositories,
  ...
}:

{
  imports = [
    ./live-common.nix
  ];

  sdImage.compressImage = false;

  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  hardware.raspberry-pi.config."all".base-dt-params.pciex1_no_l0s.enable = true;

  environment.systemPackages = [ pkgs.raspberrypi-eeprom ];
}
