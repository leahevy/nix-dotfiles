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

  options = {
    basePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "black"
        "isort"
        "mypy"
        "requests"
        "python-dotenv"
        "python-lsp-server"
        "debugpy"
      ];
      description = "Extra Python packages addable by other modules.";
    };
    additionalPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra Python packages addable by other modules.";
    };
  };

  module = {
    home =
      {
        config,
        basePackages,
        additionalPackages,
        ...
      }:
      let
        allPackages = additionalPackages ++ basePackages;
      in
      {
        home.packages = [
          (pkgs.${self.variables.pythonName}.withPackages (p: map (pkg: p.${pkg}) allPackages))
        ];
      };
  };
}
