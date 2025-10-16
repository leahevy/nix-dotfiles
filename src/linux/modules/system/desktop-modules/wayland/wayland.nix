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
  name = "wayland";

  group = "desktop-modules";
  input = "linux";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      environment.sessionVariables = {
        ELECTRON_OZONE_PLATFORM_HINT = "x11";
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
        QT_QPA_PLATFORM = "wayland";
        GDK_BACKEND = "wayland";
        SDL_VIDEODRIVER = "wayland";
        _JAVA_AWT_WM_NONPARENTING = "1";
        GSK_RENDERER = "ngl";
      };
    };
}
