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
  name = "mnt";

  group = "system";
  input = "linux";

  module = {
    linux.system = config: {
      systemd.tmpfiles.settings."mnt"."/mnt".d = {
        mode = "0755";
        user = "root";
        group = "root";
      };
    };
  };
}
