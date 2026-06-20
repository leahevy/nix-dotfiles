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
  name = "unfree";

  group = "core";
  input = "build";

  rawOptions = {
    nx.unfree = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "All allowed unfree package names for this build";
    };
  };

  module = {
    enabled = config: {
      nx.unfree =
        (self.variables.allowedUnfreePackages or [ ])
        ++ (self.host.allowedUnfreePackages or [ ])
        ++ (self.user.allowedUnfreePackages or [ ]);
    };
  };
}
