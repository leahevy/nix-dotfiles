args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  agentProgram = {
    purpose = "running Python";
    section = "languages";
    order = 40;
    skip = true;
  };
in
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
    enabled = config: {
      nx.common.dev.agents.programs.python3 = agentProgram;

      nx.common.git.git.globalIgnores = [
        "__pycache__/"
        "*.py[cod]"
        "pyrightconfig.json"
        "pip-log.txt"
        ".venv"
        "eggs/"
        "sdist/"
        "*.egg-info"
        "*.egg"
        ".coverage"
        "coverage.xml"
        "docs/_build/"
      ];
    };

    disabled = config: {
      nx.common.dev.agents.programs.python3 = agentProgram // {
        available = false;
      };
    };

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
          (pkgs.python3.withPackages (p: map (pkg: p.${pkg}) allPackages))
        ];
      };
  };
}
