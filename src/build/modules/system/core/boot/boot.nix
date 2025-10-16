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
let
  host = self.host;
in
{
  name = "boot";
  group = "core";
  input = "build";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      boot = {
        kernelModules = host.kernel.nixModules or [ ];
        extraModulePackages = host.kernel.extraModulePackages or [ ];
        kernelParams = [ "resume=/dev/vgmain/swap" ];
        initrd = {
          availableKernelModules = host.kernel.bootModules or [ ];
          kernelModules = host.kernel.initrdModules or [ ];
        };

        kernelPackages =
          if host.kernel.variant == "latest" then
            pkgs.linuxKernel.packages.${self.variables.latestLinux}
          else if host.kernel.variant == "lts" then
            pkgs.linuxKernel.packages.${self.variables.ltsLinux}
          else if host.kernel.variant == "hardened" then
            pkgs.linuxKernel.packages.${self.variables.hardenedLinux}
          else
            throw "Did not find a Linux kernel for chosen variant '${host.kernel.variant}'!";

        loader = {
          systemd-boot = {
            enable = true;
            consoleMode = "max";
          };

          efi.canTouchEfiVariables = true;
        };
      };
    };
}
