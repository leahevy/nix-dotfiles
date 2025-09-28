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
  name = "bemoji";

  submodules = {
    linux = {
      desktop-modules = {
        fuzzel = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isModuleEnabled "desktop.niri";
    in
    {
      home.packages = [ pkgs.bemoji ];

      home.sessionVariables = {
        BEMOJI_PICKER_CMD = "fuzzel -d";
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".local/share/bemoji"
        ];
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Period" = {
              action = spawn-sh "bemoji";
              hotkey-overlay.title = "Utils:Emoji picker";
            };
          };
        };
      };
    };
}
