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
  name = "keyboard-cowboy";

  group = "desktop";
  input = "darwin";

  assertions = [
    {
      assertion = !self.isModuleEnabled "desktop.yabai";
      message = "Keyboard-Cowboy and yabai are mutually exclusive!";
    }
  ];

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "keyboard-cowboy" ];
    };
  };
}
