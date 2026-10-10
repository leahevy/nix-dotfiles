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
  name = "xwayland-satellite";

  group = "desktop-modules";
  input = "linux";

  module = {
    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          string = "xwayland-satellite.*No last focused toplevel, cannot focus window";
          user = true;
          unitless = true;
        }
        {
          string = "xwayland-satellite.*unrecognized message: \"_NET_REQUEST_FRAME_EXTENTS\"";
          user = true;
          unitless = true;
        }
        {
          string = "xwayland-satellite.*Window with same serial.*has been destroyed";
          user = true;
          unitless = true;
        }
      ];
    };

    linux.system = config: {
      environment.systemPackages = with pkgs; [
        xwayland-satellite
      ];
    };
  };
}
