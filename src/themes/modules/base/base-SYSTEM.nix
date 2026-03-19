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
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      environment.etc = {
        "nx-theme/current-theme".text = config.nx.preferences.theme.name;
        "nx-theme/current-theme-config.json".text = builtins.toJSON config.nx.preferences.theme;
        "nx-theme/active-${config.nx.preferences.theme.name}".text = "";
      }
      // builtins.listToAttrs (
        map (name: {
          name = "nx-theme/available-themes/${name}";
          value = {
            text = "";
          };
        }) self.availableThemes
      );
    };
}
