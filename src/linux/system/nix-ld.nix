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
  name = "nix-ld";

  group = "system";
  input = "linux";

  disableOnTestingVM = true;

  settings = {
    baseLibraries = with args.pkgs; [
      stdenv.cc.cc.lib
      gcc.cc.lib
      zlib
      glib
      dbus
      expat
      krb5
      nss
      nspr
      openssl
      curl
    ];
    desktopLibraries = with args.pkgs; [
      libx11
      libxrandr
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrender
      libxtst
      libxau
      libxdmcp
      libxcb
      libGL
      libdrm
      mesa
      wayland
      libxkbcommon
      freetype
      fontconfig
      alsa-lib
      icu
    ];
    additionalLibraries = [ ];
  };

  module = {
    system =
      config:
      let
        hasDesktop = self.host.settings.system.desktop != null;
        desktopLibs = if hasDesktop then self.settings.desktopLibraries else [ ];
      in
      {
        # nix-ld is already enabled through build modules.
        programs.nix-ld = {
          libraries = self.settings.baseLibraries ++ desktopLibs ++ self.settings.additionalLibraries;
        };
      };
  };
}
