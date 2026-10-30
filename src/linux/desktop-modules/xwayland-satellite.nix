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
          string = "xwayland-satellite.*unrecognized message:";
          user = true;
          unitless = true;
        }
        {
          string = "xwayland-satellite.*Window with same serial.*has been destroyed";
          user = true;
          unitless = true;
        }
        {
          string = "xwayland-satellite.*Couldn't find output .*, primary output will be wrong";
          user = true;
          unitless = true;
        }
        {
          string = "xwayland-satellite.*Mixed output scales detected, choosing to give apps the smallest detected scale";
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
