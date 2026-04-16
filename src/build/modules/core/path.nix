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
  name = "path";
  group = "core";
  input = "build";

  module = {
    home = config: {
      home.sessionPath = [
        "${self.user.home}/.local/bin"
      ];
    };
  };
}
