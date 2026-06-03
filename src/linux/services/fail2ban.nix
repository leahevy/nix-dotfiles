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
  name = "fail2ban";

  group = "services";
  input = "linux";

  options = {
    pushoverOnBan = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Send a Pushover notification when fail2ban bans an IP.";
    };
  };

  module = {
    linux.system = config: {
      services.fail2ban = {
        enable = true;
      };

      environment.persistence."${self.persist}" = {
        directories = [
          "/var/lib/fail2ban"
        ];
      };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "fail2ban.service" ];
      };
    };

    ifEnabled.linux.notifications.pushover = {
      linux.system =
        { config, pushoverOnBan, ... }:
        lib.mkIf pushoverOnBan {
          nx.linux.monitoring.journal-watcher.ignorePatterns = [
            { service = "fail2ban-pushover.service"; }
          ];

          systemd.services.fail2ban-pushover = {
            description = "Pushover notifications for fail2ban ban events";
            after = [
              "fail2ban.service"
              "network-online.target"
            ];
            requires = [ "fail2ban.service" ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              User = "root";
              Restart = "always";
              RestartSec = "5";
              ExecStart = pkgs.writeShellScript "fail2ban-pushover" ''
                ${pkgs.systemd}/bin/journalctl -u fail2ban.service -f -n 0 --output=cat | \
                  while IFS= read -r _line; do
                    if [[ "$_line" =~ NOTICE[[:space:]]+\[([^\]]+)\][[:space:]]Ban[[:space:]]+([^[:space:]]+) ]]; then
                      _jail="''${BASH_REMATCH[1]}"
                      _ip="''${BASH_REMATCH[2]}"
                      ${config.nx.linux.notifications.pushover.send {
                        title = "Fail2ban";
                        message = "Banned $_ip in jail $_jail";
                        shellVars = true;
                        type = "warn";
                      }}
                    fi
                  done
              '';
            };
          };
        };
    };
  };
}
