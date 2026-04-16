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
  name = "keepassxc";

  group = "passwords";
  input = "darwin";

  submodules = {
    common = {
      passwords = {
        keepassxc = true;
      };
    };
  };

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "keepassxc" ];
    };
  };
}
