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
  name = "conda";

  group = "dev";
  input = "darwin";

  submodules = {
    common = {
      dev = {
        conda = true;
      };
    };
  };

  on = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "miniconda" ];
    };
  };
}
