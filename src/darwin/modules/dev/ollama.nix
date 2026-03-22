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
  name = "ollama";

  group = "dev";
  input = "darwin";

  assertions = [
    {
      assertion = !(self.common.isModuleEnabled "services.ollama");
      message = "darwin ollama (homebrew) and common ollama (home-manager service) are mutually exclusive!";
    }
  ];

  on = {
    darwin.home = config: {
      nx.homebrew.brews = [ "ollama" ];
    };
  };
}
