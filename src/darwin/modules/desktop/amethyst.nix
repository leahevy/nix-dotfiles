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
  name = "amethyst";

  group = "desktop";
  input = "darwin";

  submodules = {
    darwin = {
      desktop = {
        keyboard-cowboy = true;
      };
    };
  };

  assertions = [
    {
      assertion = !self.isModuleEnabled "desktop.yabai";
      message = "Yabai and amethyst are mutually exclusive!";
    }
  ];

  on = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "amethyst" ];
    };
  };
}
