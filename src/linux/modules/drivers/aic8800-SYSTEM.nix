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
rec {
  name = "aic8800";
  description = "Aicsemi AIC8800 Wi-Fi driver";

  group = "drivers";
  input = "linux";
  namespace = "system";

  unfree = [ "aic8800" ];

  configuration =
    context@{ config, options, ... }:
    let
      aic8800Package = config.boot.kernelPackages.callPackage (
        { kernel, fetchFromGitHub, ... }:
        pkgs.stdenv.mkDerivation {
          pname = "aic8800";
          version = "0.1";

          src = fetchFromGitHub {
            owner = "shenmintao";
            repo = "aic8800d80";
            rev = "f05d986fbda259698e7d82f861f39e119456a6fa";
            sha256 = "sha256-/qWNr/Rd0pOEWZN4WSknK72dKqe5bH0WUMb8228M8g0=";
          };

          nativeBuildInputs = kernel.moduleBuildDependencies;
          makeFlags = kernel.makeFlags ++ [
            "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
          ];
          installFlags = [
            "INSTALL_MOD_PATH=${placeholder "out"}"
            "MODDESTDIR=${placeholder "out"}/lib/modules/${kernel.modDirVersion}/kernel/drivers/net/wireless/aic8800"
          ];
          buildFlags = [ "modules" ];
          installTargets = [ "install" ];

          preBuild = ''
            cp -r $src/* .
            cd drivers/aic8800
            sed -i '/\/sbin\/depmod/d' Makefile
          '';

          postInstall = ''
            cd ../..
            mkdir -p $out/lib/firmware
            cp -r fw/aic8800D80 fw/aic8800DC $out/lib/firmware/

            mkdir -p $out/etc/udev/rules.d
            sed 's|/usr/bin/eject|${pkgs.util-linux}/bin/eject|g' aic.rules > $out/etc/udev/rules.d/99-aic8800.rules
          '';

          meta = with lib; {
            inherit description;
            license = licenses.unfree;
            platforms = platforms.linux;
          };
        }
      ) { };
    in
    {
      boot.extraModulePackages = [ aic8800Package ];
      boot.kernelModules = [ "aic8800_fdrv" ];
      hardware.firmware = [ aic8800Package ];
      services.udev.packages = [ aic8800Package ];
    };
}
