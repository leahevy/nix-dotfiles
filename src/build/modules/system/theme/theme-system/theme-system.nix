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
    else
      self.variables.defaultTheme;
in
{
  name = "theme-system";
  group = "theme";
  input = "build";
  namespace = "system";

  submodules = {
    themes = {
      themes = {
        ${activeTheme} = true;
      };
    };
  };
}
