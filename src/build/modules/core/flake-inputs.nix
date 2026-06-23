args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "flake-inputs";

  group = "core";
  input = "build";

  module =
    let
      excludedInputs = defs.moduleInputsToScan ++ [
        "self"
        "newestFlake"
        "lib"
      ];

      symlinkInputs = builtins.removeAttrs self.inputs excludedInputs;

      inputSource =
        input:
        if builtins.typeOf input == "path" then
          input
        else if builtins.typeOf input == "set" && input ? outPath then
          builtins.toPath input.outPath
        else
          throw "build.core.flake-inputs only supports path inputs or flake inputs with outPath!";

      mkInputLinks =
        basePath:
        lib.mapAttrs' (name: input: {
          name = "${basePath}/${name}";
          value.source = inputSource input;
        }) symlinkInputs;
    in
    {
      standalone = config: {
        home.file = mkInputLinks ".local/share/nx/inputs";
      };

      linux.system = config: {
        environment.etc = lib.mapAttrs' (name: input: {
          name = "nx/inputs/${name}";
          value = {
            source = inputSource input;
          };
        }) symlinkInputs;
      };
    };
}
