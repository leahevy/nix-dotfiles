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

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "qutebrowser" ];
    };
  };
}
