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
  name = "opengl";

  group = "graphics";
  input = "linux";
  namespace = "system";

  settings = {
    withIntel = false;
  };

  assertions = [
    {
      assertion = self.user.isModuleEnabled "graphics.opengl";
      message = "Requires linux.graphics.opengl home module to be enabled for integrated user!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages =
          with pkgs;
          [
            libva-vdpau-driver
            libvdpau-va-gl
          ]
          ++ lib.optionals self.settings.withIntel [
            intel-media-driver
            vaapiIntel
          ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          libvdpau
        ];
      };
    };
}
