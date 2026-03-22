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
  name = "bitwarden";

  group = "passwords";
  input = "darwin";

  submodules = {
    common = {
      passwords = {
        bitwarden = true;
      };
    };
  };

  on = {
    darwin.home = config: {
      nx.homebrew.casks = [ "bitwarden" ];
    };
  };
}
