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

  module = {
    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          string = "Namespace .* is not supported";
          user = true;
        }
        {
          string = "Choosing gtk\\.portal for .* as a last-resort fallback";
          user = true;
        }
        {
          string = "Could not find slot.*CreateMonitor";
          user = true;
        }
        {
          string = "A backend call failed: No such method 'CreateMonitor'";
          user = true;
        }
        {
          string = "Failed to associate portal window with parent window";
          user = true;
        }
        {
          string = "Failed to register with host portal.*App info not found";
          user = true;
        }
        {
          string = "Failed to register with host portal.*Connection already associated with an application ID";
          user = true;
        }
        {
          string = "Failed to close session implementation: GDBus\\.Error:org\\.freedesktop\\.DBus\\.Error\\.UnknownObject";
          user = true;
        }
        {
          string = "GDBus\\.Error:org\\.freedesktop\\.DBus\\.Error\\.ServiceUnknown: The name is not activatable";
          user = true;
        }
        {
          string = "Ignoring duplicate name";
          user = true;
          unitless = true;
        }
        {
          string = "Service file .* is not named after the D-Bus name";
          user = true;
          unitless = true;
        }
      ];
    };

    linux.system = config: {
      services.dbus = {
        enable = true;
        implementation = "broker";
      };
    };
  };
}
