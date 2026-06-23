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
  name = "tmpfiles";

  group = "system";
  input = "build";

  module = {
    linux.system = config: {
      systemd.tmpfiles.settings."base-dirs" = {
        "/sbin".d = {
          mode = "0755";
          user = "root";
          group = "root";
        };
      };
    };
  };
}
