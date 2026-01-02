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
      self.user.settings.desktopPreferences.secondary
    else
      self.variables.defaultDesktop.secondary;
in
{
  name = "secondary";
  group = "desktop";
  input = "build";
  namespace = "home";

  submodules = {
    desktops = {
      base = {
        secondary = true;
      };
      secondary = {
        ${activeDesktop} = true;
      };
    };
  };
}
