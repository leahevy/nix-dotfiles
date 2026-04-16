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
  name = "xwayland-satellite";

  group = "desktop-modules";
  input = "linux";

  module = {
    linux.system = config: {
      environment.systemPackages = with pkgs; [
        xwayland-satellite
      ];
    };
  };
}
