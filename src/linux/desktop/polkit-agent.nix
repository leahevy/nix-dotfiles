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
  name = "polkit-agent";
  description = "Graphical polkit authentication agent";

  group = "desktop";
  input = "linux";

  module = {
    ifEnabled.linux.desktop.niri.enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          tag = "polkit-mate-authentication-agent-1";
          string = "g_variant_new_string: assertion 'string != NULL' failed";
          user = true;
          unitless = true;
        }
      ];
    };

    ifEnabled.linux.desktop.niri.home = config: {
      systemd.user.services.polkit-agent = {
        Unit = {
          Description = "Polkit Authentication Agent";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = "${helpers.packageFile args pkgs.mate-polkit
            "libexec/polkit-mate-authentication-agent-1"
          }";
          Restart = "always";
          RestartSec = "2s";
          Type = "simple";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
  };
}
