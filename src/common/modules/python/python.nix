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

  settings = {
    basePackages = [
      "black"
      "isort"
      "mypy"
      "requests"
      "python-dotenv"
      "python-lsp-server"
      "debugpy"
    ];
    additionalPackages = [ ];
  };

  options = {
    additionalPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra Python packages addable by other modules.";
    };
  };

  on = {
    home =
      config:
      let
        optionPackages = (self.options config).additionalPackages;
        allPackages = self.settings.basePackages ++ self.settings.additionalPackages ++ optionPackages;
      in
      {
        home.packages = with pkgs; [
          (python313.withPackages (p: map (pkg: p.${pkg}) allPackages))
        ];
      };
  };
}
