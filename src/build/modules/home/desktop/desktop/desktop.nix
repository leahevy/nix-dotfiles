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
  desktopSetting = self.host.settings.system.desktop or self.user.settings.desktop or null;
  isLinux = self ? isLinux && self.isLinux;
  isDarwin = self ? isDarwin && self.isDarwin;
in
{
  name = "desktop";

  assertions = lib.optionals (desktopSetting != null) [
    {
      assertion =
        if isLinux then
          lib.elem desktopSetting defs.allowedLinuxDesktops
        else if isDarwin then
          lib.elem desktopSetting defs.allowedDarwinDesktops
        else
          false;
      message =
        if isLinux then
          "Desktop '${desktopSetting}' is not supported on Linux. Allowed desktops: ${lib.concatStringsSep ", " defs.allowedLinuxDesktops}"
        else if isDarwin then
          "Desktop '${desktopSetting}' is not supported on Darwin. Allowed desktops: ${lib.concatStringsSep ", " defs.allowedDarwinDesktops}"
        else
          "Desktop environments are not supported on this platform";
    }
  ];

  submodules =
    if desktopSetting != null then
      if isLinux then
        {
          linux = {
            desktop = {
              ${desktopSetting} = true;
            };
          };
        }
      else if isDarwin then
        {
          darwin = {
            desktop = {
              ${desktopSetting} = true;
            };
          };
        }
      else
        { }
    else
      { };
}
