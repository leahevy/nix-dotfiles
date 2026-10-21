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
  name = "harmonia";
  description = "Self-hosted Nix binary cache";

  group = "server";
  input = "linux";

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "cache";
      description = "Subdomain under baseDomain for the harmonia binary cache vhost.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Port harmonia listens on (localhost only, nginx fronts it).";
    };

    restrictToClientNetwork = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restrict the nginx vhost to permitted client IPs via the nx_is_allowed geo variable.";
    };

    prefetchBranch = lib.mkOption {
      type = lib.types.str;
      default = "update-flake-inputs";
      description = "nxcore branch name carrying the weekly flake lock update PR.";
    };

    prefetchSchedule = lib.mkOption {
      type = lib.types.str;
      default = "Thu *-*-* 19:00:00";
      description = "OnCalendar expression for the prefetch timer (systemd calendar format).";
    };

    prefetchStateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/nx-harmonia-builds";
      description = "Directory for GC root symlinks from the prefetch service.";
    };
  };

  module = {
    enabled = config: {
      nx.packages.extra = [ pkgs.harmonia ];
    };

    linux.system =
      {
        config,
        subdomain,
        port,
        restrictToClientNetwork,
        prefetchBranch,
        prefetchSchedule,
        prefetchStateDir,
        ...
      }:
      let
        exposedService = self.host.remote.exposedServices.harmonia or null;
        nxcoreURL = self.variables.coreRepoURL or "";
        dummyAge = "age1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq";

        prefetchEvalLibWrapper = pkgs.writeShellScript "nx-harmonia-te-eval-lib" ''
          source "$REAL_TE_LIB_PATH"
          te_eval() { te_build "$@"; }
        '';
      in
      {
        assertions = [
          {
            assertion = exposedService == null || exposedService.subdomain == subdomain;
            message = "linux.server.harmonia: subdomain '${subdomain}' does not match exposedServices.harmonia.subdomain '${
              if exposedService != null then exposedService.subdomain else ""
            }'!";
          }
          {
            assertion = nxcoreURL != "";
            message = "linux.server.harmonia prefetch requires variables.coreRepoURL to be set!";
          }
        ];

        sops.secrets."harmonia-sign-key" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "harmonia-sign-key";
          owner = "root";
          mode = "0400";
        };

        services.harmonia.cache = {
          enable = true;
          signKeyPaths = [ config.sops.secrets."harmonia-sign-key".path ];
          settings.bind = "127.0.0.1:${toString port}";
          settings.priority = 30;
        };

        users.users.nx-harmonia-prefetch = {
          isSystemUser = true;
          group = "nx-harmonia-prefetch";
          home = "/var/lib/nx-harmonia-prefetch";
        };
        users.groups.nx-harmonia-prefetch = { };

        nix.settings.allowed-users = lib.mkForce [ "nx-harmonia-prefetch" ];

        systemd.tmpfiles.settings."nx-harmonia-builds" = {
          "/var/lib/nx-harmonia-prefetch".d = {
            mode = "0700";
            user = "nx-harmonia-prefetch";
            group = "nx-harmonia-prefetch";
          };
          "${prefetchStateDir}".d = {
            mode = "0700";
            user = "nx-harmonia-prefetch";
            group = "nx-harmonia-prefetch";
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}${prefetchStateDir}".d = {
            mode = "0700";
            user = "nx-harmonia-prefetch";
            group = "nx-harmonia-prefetch";
          };
        };

        environment.persistence = lib.mkIf self.host.impermanence {
          "${self.persist}".directories = [ prefetchStateDir ];
        };

        systemd.services.nx-harmonia-prefetch = {
          description = "Harmonia pre-fetch: pull NixOS closures into local cache";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = "nx-harmonia-prefetch";
            ExecStart = toString (
              pkgs.writeShellScript "nx-harmonia-prefetch" ''
                set -euo pipefail

                exec 9>/var/lib/nx-harmonia-prefetch/.lock
                if ! ${pkgs.util-linux}/bin/flock -n 9; then
                  ${pkgs.coreutils}/bin/echo "Another prefetch run is already in progress, exiting."
                  exit 0
                fi
                _prefetch_tmpdir=$(${pkgs.coreutils}/bin/mktemp -d /var/lib/nx-harmonia-prefetch/work.XXXXXX)
                trap '${pkgs.coreutils}/bin/rm -rf "$_prefetch_tmpdir" 2>/dev/null || true' EXIT TERM INT

                NXCORE_URL="${nxcoreURL}"
                BRANCH="${prefetchBranch}"

                GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
                  ${pkgs.git}/bin/git clone --branch main "$NXCORE_URL" "$_prefetch_tmpdir/nxcore"

                if GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
                    ${pkgs.git}/bin/git ls-remote --heads "$NXCORE_URL" "$BRANCH" \
                    | ${pkgs.gnugrep}/bin/grep -q .; then
                  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
                    ${pkgs.git}/bin/git -C "$_prefetch_tmpdir/nxcore" fetch origin "$BRANCH"
                  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
                    ${pkgs.git}/bin/git -C "$_prefetch_tmpdir/nxcore" \
                      -c user.name="nx-harmonia-prefetch" \
                      -c user.email="nx-harmonia-prefetch@localhost" \
                      merge --no-edit "origin/$BRANCH"
                  ${pkgs.coreutils}/bin/echo "Merged branch '$BRANCH' into main for prefetch."
                else
                  ${pkgs.coreutils}/bin/echo "Branch '$BRANCH' not found, prefetching plain main."
                fi

                source "$_prefetch_tmpdir/nxcore/scripts/utils/defs.sh"

                GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
                  ${pkgs.git}/bin/git clone --depth=1 "$TEST_EVAL_TEMPLATE_REPO_URL" "$_prefetch_tmpdir/template"
                ${pkgs.coreutils}/bin/rm -rf "$_prefetch_tmpdir/template/.git"

                ${pkgs.coreutils}/bin/cp -r "$_prefetch_tmpdir/nxcore/.github/test-config/." "$_prefetch_tmpdir/template/"

                while IFS= read -r SOPS_FILE; do
                  ${pkgs.gnused}/bin/sed -i "s/@SOPS_AGE_PUBLIC_KEY@/${dummyAge}/g" "$SOPS_FILE"
                done < <(${pkgs.gnugrep}/bin/grep -rl '@SOPS_AGE_PUBLIC_KEY@' "$_prefetch_tmpdir/template/profiles" 2>/dev/null || true)

                ${pkgs.coreutils}/bin/mkdir -p "$_prefetch_tmpdir/scripts-wrap/test-evals.d"
                ${pkgs.coreutils}/bin/cp -r "$_prefetch_tmpdir/nxcore/.github/scripts/test-evals.d/." \
                  "$_prefetch_tmpdir/scripts-wrap/test-evals.d/"
                ${pkgs.coreutils}/bin/cp ${prefetchEvalLibWrapper} "$_prefetch_tmpdir/scripts-wrap/test-eval-lib.sh"

                export REAL_TE_LIB_PATH="$_prefetch_tmpdir/nxcore/.github/scripts/test-eval-lib.sh"
                export TE_BUILD_STATE_DIR="${prefetchStateDir}"
                export TE_CORE_DIR="$_prefetch_tmpdir/nxcore"
                export TE_TEMPLATE_DIR="$_prefetch_tmpdir/template"
                export TE_DUMMY_AGE_PUBLIC_KEY="${dummyAge}"
                export TE_FIXED_EVAL_TIMESTAMP="0"
                export TE_RESULTS_TSV="/dev/null"

                _cache_retry=0
                _cache_max_retries=5
                _cache_wait=10
                until ${pkgs.curl}/bin/curl -sf https://cache.nixos.org/nix-cache-info >/dev/null 2>&1; do
                  _cache_retry=$((_cache_retry + 1))
                  if [[ $_cache_retry -ge $_cache_max_retries ]]; then
                    ${pkgs.coreutils}/bin/echo "cache.nixos.org not reachable after $_cache_max_retries attempts, aborting prefetch."
                    exit 1
                  fi
                  ${pkgs.coreutils}/bin/echo "cache.nixos.org not reachable, retrying in ''${_cache_wait}s... (attempt $_cache_retry/$_cache_max_retries)"
                  ${pkgs.coreutils}/bin/sleep $_cache_wait
                  _cache_wait=$((_cache_wait * 2))
                done

                _prefetch_ok=0
                _prefetch_total=0
                for EVAL_SCRIPT in "$_prefetch_tmpdir/scripts-wrap/test-evals.d/"[0-9]*.sh; do
                  CASE_NAME=$(${pkgs.coreutils}/bin/basename "$EVAL_SCRIPT" .sh)
                  CASE_NAME="''${CASE_NAME#[0-9][0-9]-}"
                  export TE_CASE_NAME="$CASE_NAME"
                  _prefetch_total=$((_prefetch_total + 1))
                  ${pkgs.coreutils}/bin/echo "Pre-fetching test case: $CASE_NAME ..."
                  if ${pkgs.bash}/bin/bash "$EVAL_SCRIPT" 2>&1; then
                    ${pkgs.coreutils}/bin/echo "OK: $CASE_NAME"
                    _prefetch_ok=$((_prefetch_ok + 1))
                  else
                    ${pkgs.coreutils}/bin/echo "WARN: prefetch failed for $CASE_NAME - non-fatal."
                  fi
                done

                _path_min=999999999
                _path_max=0
                _path_sum=0
                for _gc_root in "${prefetchStateDir}"/prefetch-*; do
                  [[ -L "$_gc_root" ]] || continue
                  [[ "$_gc_root" == *.drv ]] && continue
                  _n=$(${config.nix.package.out}/bin/nix path-info --recursive \
                    "$(${pkgs.coreutils}/bin/readlink -f "$_gc_root")" 2>/dev/null \
                    | ${pkgs.coreutils}/bin/wc -l)
                  _path_sum=$((_path_sum + _n))
                  [[ $_n -lt $_path_min ]] && _path_min=$_n
                  [[ $_n -gt $_path_max ]] && _path_max=$_n
                done

                if [[ $_path_sum -eq 0 ]]; then _path_min=0; fi
                ${pkgs.coreutils}/bin/printf 'Min: %d Max: %d Sum: %d paths\n' \
                  "$_path_min" "$_path_max" "$_path_sum" \
                  | ${pkgs.coreutils}/bin/tee "${prefetchStateDir}/last-success-stats" > /dev/null
                if [[ $_prefetch_total -gt 0 ]]; then
                  ${pkgs.coreutils}/bin/date +%s | ${pkgs.coreutils}/bin/tee "${prefetchStateDir}/last-success" > /dev/null
                fi
                ${pkgs.coreutils}/bin/echo "Prefetch complete: $_prefetch_ok/$_prefetch_total profiles succeeded."
              ''
            );
          };
          environment =
            config.nix.envVars
            // {
              HOME = "/var/lib/nx-harmonia-prefetch";
              inherit (config.environment.sessionVariables) NIX_PATH;
            }
            // config.networking.proxy.envVars;
          path = with pkgs; [
            bash
            coreutils
            curl
            gawk
            git
            gnugrep
            gnused
            config.nix.package.out
          ];
        };

        systemd.timers.nx-harmonia-prefetch = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = prefetchSchedule;
            Persistent = true;
            RandomizedDelaySec = "30min";
          };
        };
      };

    ifEnabled.linux.server.nginx = {
      linux.system =
        {
          config,
          subdomain,
          port,
          restrictToClientNetwork,
          ...
        }:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.harmonia or null;
        in
        lib.mkIf (domain != null && exposedService != null) {
          services.nginx.virtualHosts."${subdomain}.${domain}" = {
            useACMEHost = domain;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              recommendedProxySettings = false;
              extraConfig = ''
                ${lib.optionalString restrictToClientNetwork "if ($nx_is_allowed = 0) { return 403; }"}
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_redirect off;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection $connection_upgrade;
              '';
            };
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "harmonia.service" ];
        nx.linux.server.healthchecks.dailyHealthChecks = {
          "+70 - Prefetch cache age" = ''
            _ts_file="${config.nx.linux.server.harmonia.prefetchStateDir}/last-success"
            _stats_file="${config.nx.linux.server.harmonia.prefetchStateDir}/last-success-stats"
            if [[ ! -f "$_ts_file" ]]; then
              printf 'no successful prefetch recorded\n' >&3
              exit 0
            fi
            _last=$(${pkgs.coreutils}/bin/cat "$_ts_file")
            _now=$(${pkgs.coreutils}/bin/date +%s)
            _age=$((_now - _last))
            _days=$((_age / 86400))
            _hours=$(((_age % 86400) / 3600))
            _minutes=$(((_age % 3600) / 60))
            _stats=""
            if [[ -f "$_stats_file" ]]; then
              _stats=" ($(${pkgs.coreutils}/bin/cat "$_stats_file"))"
            fi
            printf '%d days %d hours %d minutes%s\n' "$_days" "$_hours" "$_minutes" "$_stats" >&3
          '';
        };
      };
    };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.harmonia or null;
          subdomain = config.nx.linux.server.harmonia.subdomain;
        in
        lib.mkIf (domain != null && exposedService != null) {
          nx.linux.server.dashboard.services = [
            {
              name = "Nix Cache";
              href = "#admin";
              target = "_self";
              siteMonitor = "https://${subdomain}.${domain}/nix-cache-info";
              description = "Harmonia binary cache";
              icon = "nixos";
              group = "admin";
            }
          ];
        };
    };
  };
}
