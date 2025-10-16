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
  name = "firefox";

  group = "browser";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.firefox = {
        enable = true;
      };

      stylix =
        lib.mkIf
          (
            (self.user.isStandalone && self.isModuleEnabled "style.stylix")
            || (!self.user.isStandalone && self.host.isModuleEnabled "style.stylix")
          )
          {
            targets.firefox.profileNames = [
              "default-release"
            ];
          };

      home.sessionVariables = {
        MOZ_ENABLE_WAYLAND = "1";
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".mozilla"
          ".cache/mozilla/firefox"
        ];
      };
    };
}
