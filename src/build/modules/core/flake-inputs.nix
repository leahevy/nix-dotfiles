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

  rawOptions = {
    nx.flakeInputs.extra = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name to symlink this source under in nx/inputs";
            };
            source = lib.mkOption {
              type = lib.types.path;
              description = "Path to symlink such as the result of builtins.fetchTarball";
            };
          };
        }
      );
      default = [ ];
      description = "Extra non-flake sources to root under nx/inputs so they survive garbage collection";
    };
  };

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

      flakeInputEntries = lib.mapAttrsToList (name: input: {
        inherit name;
        source = input;
      }) symlinkInputs;

      mkInputLinks =
        basePath: extra:
        lib.listToAttrs (
          map (
            entry: lib.nameValuePair "${basePath}/${entry.name}" { source = inputSource entry.source; }
          ) flakeInputEntries
        )
        // lib.listToAttrs (
          map (entry: lib.nameValuePair "${basePath}/${entry.name}" { source = entry.source; }) extra
        );
    in
    {
      standalone = config: {
        home.file = mkInputLinks ".local/share/nx/inputs" config.nx.flakeInputs.extra;
      };

      linux.system = config: {
        environment.etc = mkInputLinks "nx/inputs" config.nx.flakeInputs.extra;
      };
    };
}
