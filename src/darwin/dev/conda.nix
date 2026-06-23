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

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "miniconda" ];
    };
  };
}
