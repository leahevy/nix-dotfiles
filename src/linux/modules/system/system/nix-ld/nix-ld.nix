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
  namespace = "system";

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
      xorg.libX11
      xorg.libXrandr
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrender
      xorg.libXtst
      xorg.libXau
      xorg.libXdmcp
      xorg.libxcb
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

  configuration =
    context@{ config, options, ... }:
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
}
