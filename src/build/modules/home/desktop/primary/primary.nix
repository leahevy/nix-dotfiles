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
  activeDesktop =
    if (self.user.settings.desktopPreferences or null) != null then
      self.user.settings.desktopPreferences.primary
    else
      self.variables.defaultDesktop.primary;
in
{
  name = "primary";
  group = "desktop";
  input = "build";
  namespace = "home";

  submodules = {
    desktops = {
      base = {
        primary = true;
      };
      primary = {
        ${activeDesktop} = true;
      };
    };
  };
}
