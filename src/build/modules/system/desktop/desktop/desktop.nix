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
  group = "desktop";
  input = "build";
  namespace = "system";

  submodules = {
    linux = {
      desktop =
        let
          desktopSetting = self.host.settings.system.desktop or null;
        in
        lib.optionalAttrs (desktopSetting != null) {
          ${desktopSetting} = true;
        };
    };
  };
}
