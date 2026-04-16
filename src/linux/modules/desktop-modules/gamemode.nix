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
  name = "gamemode";

  group = "desktop-modules";
  input = "linux";

  module = {
    linux.system = config: {
      programs.gamemode = {
        enable = true;
        settings = {
          general = {
            renice = 10;
          };

          custom = {
            start = self.notifyUser {
              inherit pkgs;
              title = "GameMode";
              body = "GameMode started";
              icon = "com.valvesoftware.Steam";
              urgency = "normal";
              validation = { inherit config; };
            };
            end = self.notifyUser {
              inherit pkgs;
              title = "GameMode";
              body = "GameMode ended";
              icon = "com.valvesoftware.Steam";
              urgency = "normal";
              validation = { inherit config; };
            };
          };
        };
      };
    };
  };
}
