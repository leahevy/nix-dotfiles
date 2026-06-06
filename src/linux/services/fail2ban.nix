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
      enabled =
        config:
        let
          fail2banSummaryExpr = ''
            _since=$(${pkgs.coreutils}/bin/date -d 'yesterday 00:00:00' '+%Y-%m-%d %H:%M:%S')
            _jails=$(
              ${pkgs.fail2ban}/bin/fail2ban-client status \
                | ${pkgs.gnused}/bin/sed -n 's/^`- Jail list:[[:space:]]*//p' \
                | ${pkgs.coreutils}/bin/tr ',' ' '
            )

            if [[ -z "$_jails" ]]; then
              printf '[no fail2ban jails]\n' >&3
              exit 0
            fi

            _ban_counts=$(
              ${pkgs.systemd}/bin/journalctl -u fail2ban.service --since "$_since" --output=cat --no-pager 2>/dev/null \
                | ${pkgs.gawk}/bin/awk '
                    match($0, /NOTICE[[:space:]]+\[([^\]]+)\][[:space:]]Ban[[:space:]]+([^[:space:]]+)/, m) {
                      bans[m[1]]++
                    }
                    END {
                      for (jail in bans) {
                        print jail "\t" bans[jail]
                      }
                    }
                  '
            )

            _total_today=0
            for _jail in $_jails; do
              [[ -n "$_jail" ]] || continue
              _status=$(${pkgs.fail2ban}/bin/fail2ban-client status "$_jail" 2>/dev/null || true)
              _current=$(
                printf '%s\n' "$_status" \
                  | ${pkgs.gnused}/bin/sed -n 's/^[[:space:]]*|- Currently banned:[[:space:]]*//p'
              )
              _total=$(
                printf '%s\n' "$_status" \
                  | ${pkgs.gnused}/bin/sed -n 's/^[[:space:]]*|- Total banned:[[:space:]]*//p'
              )
              _today_count=$(
                printf '%s\n' "$_ban_counts" \
                  | ${pkgs.gawk}/bin/awk -F '\t' -v jail="$_jail" '$1 == jail { print $2; found=1 } END { if (!found) print 0 }'
              )
              _total_today=$((_total_today + _today_count))
              printf '%5s ..... %s (now %s, total %s)\n' "$_today_count" "$_jail" "''${_current:-0}" "''${_total:-0}" >&3
            done

            printf '\n[total banned today: %s]\n' "$_total_today" >&3
          '';

          fail2banIPsExpr = ''
            _jails=$(
              ${pkgs.fail2ban}/bin/fail2ban-client status \
                | ${pkgs.gnused}/bin/sed -n 's/^`- Jail list:[[:space:]]*//p' \
                | ${pkgs.coreutils}/bin/tr ',' ' '
            )

            _had_ips=0
            for _jail in $_jails; do
              [[ -n "$_jail" ]] || continue
              _status=$(${pkgs.fail2ban}/bin/fail2ban-client status "$_jail" 2>/dev/null || true)
              _ips=$(
                printf '%s\n' "$_status" \
                  | ${pkgs.gnused}/bin/sed -n 's/^[[:space:]]*`- Banned IP list:[[:space:]]*//p'
              )
              [[ -n "$_ips" ]] || continue
              _had_ips=1
              printf '%s: %s\n' "$_jail" "$_ips" >&3
            done

            if [[ "$_had_ips" -eq 0 ]]; then
              exit 0
            fi
          '';
        in
        {
          nx.linux.server.healthchecks.requireServicesUp = [ "fail2ban.service" ];
          nx.linux.server.healthchecks.dailyHealthChecks = {
            "70 - Fail2ban" = fail2banSummaryExpr;
            "!75 - Fail2ban IPs" = fail2banIPsExpr;
          };
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
