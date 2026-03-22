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
  name = "qutebrowser";

  group = "browser";
  input = "darwin";

  submodules = {
    common = {
      browser = {
        qutebrowser-config = true;
      };
    };
  };

  on = {
    darwin.home = config: {
      nx.homebrew.casks = [ "qutebrowser" ];
    };
  };
}
