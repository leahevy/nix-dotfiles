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

  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "pcie_aspm=off"
  ];

  environment.systemPackages = [ pkgs.raspberrypi-eeprom ];
}
