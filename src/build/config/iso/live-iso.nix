{
  config,
  pkgs,
  lib,
  modulesPath,
  variables,
  helpers,
  nx-repositories,
  ...
}:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    ./live-common.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  isoImage.squashfsCompression = "gzip -Xcompression-level 1";
}
