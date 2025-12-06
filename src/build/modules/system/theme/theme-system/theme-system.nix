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
  activeTheme = self.host.settings.theme or self.variables.defaultTheme;
in
{
  name = "theme-system";
  group = "theme";
  input = "build";
  namespace = "system";

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
