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
  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        (python313.withPackages (
          p: with p; [
            black
            isort
            mypy
            requests
            python-dotenv
            python-lsp-server
          ]
        ))
      ];
    };
}
