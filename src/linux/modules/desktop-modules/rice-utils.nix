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
  name = "rice-utils";

  group = "desktop-modules";
  input = "linux";

  submodules = {
    common = {
      fonts = {
        japanese = true;
      };
    };
  };

  module = {
    home =
      config:
      let
        unimatrix-wrapped = pkgs.symlinkJoin {
          name = "unimatrix-wrapped";
          paths = [ pkgs.unimatrix ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/unimatrix \
              --run 'exec 2>/dev/null'
          '';
        };
      in
      {
        home = {
          packages = [
            unimatrix-wrapped
          ];

          shellAliases = {
            matrix = "unimatrix -l kkknss -i -s 96";
          };
        };
      };
  };
}
