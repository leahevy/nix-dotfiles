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
  activeTheme =
    if (self.host.settings.theme or null) != null then
      self.host.settings.theme
    else if (self.user.settings.theme or null) != null then
      self.user.settings.theme
    else
      self.variables.defaultTheme;
in
{
  name = "theme-home";
  group = "theme";
  input = "build";
  namespace = "home";

  submodules = {
    themes = {
      base = {
        base = true;
      };
      themes = {
        ${activeTheme} = true;
      };
    };
  };
}
