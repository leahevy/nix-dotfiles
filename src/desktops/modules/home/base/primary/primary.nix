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
  name = "primary";

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

      desktopConfigForJson = convertPackagesToNames self.desktop.primary;
    in
    {
      home.file = {
        ".config/nx-desktop/current-primary-desktop".text = self.desktop.primary.name;
        ".config/nx-desktop/current-primary-desktop-config.json".text =
          builtins.toJSON desktopConfigForJson;
        ".config/nx-desktop/active-primary-${self.desktop.primary.name}".text = "";
      }
      // builtins.listToAttrs (
        map (name: {
          name = ".config/nx-desktop/available-primary-desktops/${name}";
          value = {
            text = "";
          };
        }) self.availablePrimaryDesktops
      );
    };
}
