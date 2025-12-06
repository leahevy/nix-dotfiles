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
  name = "base";
  group = "base";
  input = "themes";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.file = {
        ".config/nx-theme/current-theme".text = self.theme.name;
        ".config/nx-theme/current-theme-config.json".text = builtins.toJSON self.theme;
        ".config/nx-theme/active-${self.theme.name}".text = "";
      }
      // builtins.listToAttrs (
        map (name: {
          name = ".config/nx-theme/available-themes/${name}";
          value = {
            text = "";
          };
        }) self.availableThemes
      );
    };
}
