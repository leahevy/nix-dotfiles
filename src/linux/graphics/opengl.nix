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

  module = {
    linux.home = config: {
      home.persistence."${self.persist}" = {
        directories = [
          ".cache/mesa_shader_cache"
          ".cache/mesa_shader_cache_db"
        ];
      };
    };

    linux.system = config: {
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages =
          with pkgs;
          [
            libva-vdpau-driver
            libvdpau-va-gl
          ]
          ++ lib.optionals (self.host.hardware.cpu == "intel" && self.isPhysical) [
            intel-media-driver
            intel-vaapi-driver
          ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          libvdpau
        ];
      };
    };
  };
}
