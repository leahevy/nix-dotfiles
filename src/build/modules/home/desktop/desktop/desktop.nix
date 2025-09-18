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
  name = "desktop";

  submodules =
    if self ? isLinux && self.isLinux then
      {
        linux = {
          desktop =
            let
              desktopSetting = self.host.settings.system.desktop or self.user.settings.desktop or null;
            in
            lib.optionalAttrs (desktopSetting != null) {
              ${desktopSetting} = true;
            };
        };
      }
    else
      { };
}
