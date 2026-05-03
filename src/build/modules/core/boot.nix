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
    physical.system =
      { config, ... }:
      {
        boot.kernelParams =
          let
            resumeDevices =
              if host.kernel.resumeDevice != null then
                [ host.kernel.resumeDevice ]
              else
                helpers.getDiskoResumeDevices (config.disko.devices or { });
          in
          map (dev: "resume=${dev}") resumeDevices;
      };
    system =
      config:
      let
        diskoDevices = config.disko.devices or { };
        usesLuks = (config.boot.initrd.luks.devices or { }) != { };
        usesLvm = (diskoDevices.lvm_vg or { }) != { };
        usesSystemdInitrd = config.boot.initrd.systemd.enable;
        hasDesktop = (config.nx.profile.host.settings.system.desktop or null) != null;
        isVM = config.nx.profile.isVirtual;
        kernel = host.kernel;
      in
      {
        boot = {
          kernelModules =
            (kernel.nixModules or [ ])
            ++ lib.optionals kernel.addPhysicalModules kernel.defaults.physicalModules.nixModules
            ++ lib.optionals kernel.addVMModules kernel.defaults.vmModules.nixModules
            ++ lib.optionals (
              kernel.addOpticalDriveModules && hasDesktop && !isVM
            ) kernel.defaults.opticalDriveModules.nixModules
            ++ lib.optionals kernel.addFilesystemModules kernel.defaults.filesystemModules.nixModules;
          extraModulePackages = kernel.extraModulePackages or [ ];
          initrd =
            let
              pick = set: if usesSystemdInitrd then set.systemdBootModules else set.classicBootModules;
              pickInitrd = set: if usesSystemdInitrd then set.systemdInitrdModules else set.classicInitrdModules;
            in
            {
              availableKernelModules =
                (kernel.bootModules or [ ])
                ++ lib.optionals (kernel.addPhysicalModules && !isVM) (pick kernel.defaults.physicalModules)
                ++ lib.optionals (kernel.addVMModules || isVM) (pick kernel.defaults.vmModules)
                ++ lib.optionals (kernel.addOpticalDriveModules && hasDesktop && !isVM) (
                  pick kernel.defaults.opticalDriveModules
                )
                ++ lib.optionals kernel.addFilesystemModules (pick kernel.defaults.filesystemModules)
                ++ lib.optionals (!usesSystemdInitrd && (usesLuks || usesLvm)) [ "dm_mod" ]
                ++ lib.optionals (!usesSystemdInitrd && usesLuks) [ "dm_crypt" ];
              kernelModules =
                (kernel.initrdModules or [ ])
                ++ lib.optionals (kernel.addPhysicalModules && !isVM) (pickInitrd kernel.defaults.physicalModules)
                ++ lib.optionals (kernel.addVMModules || isVM) (pickInitrd kernel.defaults.vmModules)
                ++ lib.optionals (kernel.addOpticalDriveModules && hasDesktop && !isVM) (
                  pickInitrd kernel.defaults.opticalDriveModules
                )
                ++ lib.optionals kernel.addFilesystemModules (pickInitrd kernel.defaults.filesystemModules)
                ++ lib.optionals usesLvm [ "dm-snapshot" ];
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
