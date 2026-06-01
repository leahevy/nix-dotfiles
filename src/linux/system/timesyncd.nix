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
  name = "timesyncd";

  group = "system";
  input = "linux";

  module = {
    linux.system = config: {
      services.timesyncd = {
        enable = lib.mkForce true;
      };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "systemd-timesyncd.service" ];
        nx.linux.server.healthchecks.regularHealthChecks."NTP synchronisation" = ''
          _sync=$(${pkgs.systemd}/bin/timedatectl show --property=NTPSynchronized --value 2>/dev/null || echo "no")
          if [[ "$_sync" != "yes" ]]; then
            printf 'not synchronised\n' >&3
            exit 1
          fi
        '';
      };
    };
  };
}
