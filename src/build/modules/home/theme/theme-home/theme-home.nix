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
  activeTheme = self.host.settings.theme or self.user.settings.theme or self.variables.defaultTheme;
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
