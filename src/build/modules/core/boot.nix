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

  module = {
    system = config: {
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
            if self.variables.latestLinuxOverride != null then
              pkgs.linuxKernel.packages.${self.variables.latestLinuxOverride}
            else
              pkgs.linuxPackages_latest
          else if host.kernel.variant == "lts" then
            if self.variables.ltsLinuxOverride != null then
              pkgs.linuxKernel.packages.${self.variables.ltsLinuxOverride}
            else
              pkgs.linuxPackages
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
  };
}
