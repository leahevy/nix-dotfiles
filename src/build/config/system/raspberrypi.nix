{
  inputs,
  host,
  variables,
  allOverlays,
  unfreePredicate,
  ...
}:
{ config, lib, ... }:
{
  imports =
    with inputs.nixos-raspberrypi.nixosModules;
    [
      raspberry-pi-5.base
      raspberry-pi-5.page-size-16k
      raspberry-pi-5.display-vc4
      raspberry-pi-5.bluetooth
      trusted-nix-caches
    ]
    ++ lib.optionals (host.settings.system.desktop == null) [
      inputs.nixos-raspberrypi.lib.inject-overlays-global
    ];

  nixpkgs.overlays = allOverlays ++ [
    (final: prev: {
      python313 = prev.python313.override {
        packageOverrides = _: pprev: {
          cryptography = pprev.cryptography.overrideAttrs (_: {
            dontUsePytestCheck = true;
          });
        };
      };
    })
  ];
  nixpkgs.config.allowUnfreePredicate = unfreePredicate;
  nixpkgs.config.permittedInsecurePackages = variables.releaseTransitionInsecurePackages or [ ];

  boot.loader.raspberry-pi.bootloader = "kernel";

  assertions = [
    {
      assertion =
        (config.boot.initrd.luks.devices or { }) == { }
        || host.ethernetDeviceName != null
        || !builtins.elem (host.deploymentMode or "develop") [
          "server"
          "managed"
        ];
      message = "Raspberry Pi 5 with encrypted (LUKS) devices in server or managed mode requires host.ethernetDeviceName to be set: remote initrd LUKS unlock works over wired ethernet only!";
    }
  ];
}
