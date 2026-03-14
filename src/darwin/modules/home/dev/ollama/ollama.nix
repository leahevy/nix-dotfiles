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
  namespace = "home";

  submodules = {
    darwin = {
      software = {
        homebrew = true;
      };
    };
  };

  assertions = [
    {
      assertion = !(self.common.isModuleEnabled "services.ollama");
      message = "darwin ollama (homebrew) and common ollama (home-manager service) are mutually exclusive!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/ollama.brew".text = ''
        brew 'ollama'
      '';
    };

}
