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
  name = "kitty";

  group = "terminal";
  input = "common";

  settings = {
    setEnv = false;
  };

  on = {
    home = config: {
      programs.kitty = {
        enable = true;
        settings = { };
      };

      home.sessionVariables = lib.mkIf self.settings.setEnv {
        TERMINAL = "kitty";
      };

      home.persistence."${self.persist.home}" = {
        directories = [
          ".cache/kitty"
        ];
      };
    };
  };
}
