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
  name = "dbus";

  group = "services";
  input = "linux";

  on = {
    linux.system = config: {
      services.dbus = {
        enable = true;
        implementation = "broker";
      };
    };
  };
}
