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
  name = "secondary";

  group = "base";
  input = "desktops";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    let
      packageToName = pkg: pkg.pname or pkg.name or (builtins.toString pkg);

      convertPackagesToNames =
        value:
        if builtins.isAttrs value && value ? type && value.type or null == "derivation" then
          packageToName value
        else if builtins.isList value then
          map convertPackagesToNames value
        else if builtins.isAttrs value then
          lib.mapAttrs (_: convertPackagesToNames) value
        else
          value;

      desktopConfigForJson = convertPackagesToNames self.desktop.secondary;
    in
    {
      home.file = {
        ".config/nx-desktop/current-secondary-desktop".text = self.desktop.secondary.name;
        ".config/nx-desktop/current-secondary-desktop-config.json".text =
          builtins.toJSON desktopConfigForJson;
        ".config/nx-desktop/active-secondary-${self.desktop.secondary.name}".text = "";
      }
      // builtins.listToAttrs (
        map (name: {
          name = ".config/nx-desktop/available-secondary-desktops/${name}";
          value = {
            text = "";
          };
        }) self.availableSecondaryDesktops
      );
    };
}
