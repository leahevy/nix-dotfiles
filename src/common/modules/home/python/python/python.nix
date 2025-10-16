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
  name = "python";

  group = "python";
  input = "common";
  namespace = "home";

  defaults = {
    basePackages = [
      "black"
      "isort"
      "mypy"
      "requests"
      "python-dotenv"
      "python-lsp-server"
    ];
    additionalPackages = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        (python313.withPackages (
          p: map (pkg: p.${pkg}) (self.settings.basePackages ++ self.settings.additionalPackages)
        ))
      ];
    };
}
