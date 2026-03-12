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

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/ollama.brew".text = ''
        brew 'ollama'
      '';
    };

}
