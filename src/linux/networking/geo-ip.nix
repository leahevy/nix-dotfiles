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
let
  validCodes = lib.concatLists (
    map (lib.splitString "|") [
      "ad|ae|af|ag|ai|al|am|ao|aq|ar|as|at|au|aw|ax|az"
      "ba|bb|bd|be|bf|bg|bh|bi|bj|bl|bm|bn|bo|bq|br|bs|bt|bw|by|bz"
      "ca|cd|cf|cg|ch|ci|ck|cl|cm|cn|co|cr|cu|cv|cw|cy|cz"
      "de|dj|dk|dm|do|dz"
      "ec|ee|eg|er|es|et"
      "fi|fj|fk|fm|fo|fr"
      "ga|gb|gd|ge|gf|gg|gh|gi|gl|gm|gn|gp|gq|gr|gt|gu|gw|gy"
      "hk|hn|hr|ht|hu"
      "id|ie|il|im|in|io|iq|ir|is|it"
      "je|jm|jo|jp"
      "ke|kg|kh|ki|km|kn|kp|kr|kw|ky|kz"
      "la|lb|lc|li|lk|lr|ls|lt|lu|lv|ly"
      "ma|mc|md|me|mf|mg|mh|mk|ml|mm|mn|mo|mp|mq|mr|ms|mt|mu|mv|mw|mx|my|mz"
      "na|nc|ne|nf|ng|ni|nl|no|np|nr|nu|nz"
      "om"
      "pa|pe|pf|pg|ph|pk|pl|pm|pr|ps|pt|pw|py"
      "qa"
      "re|ro|rs|ru|rw"
      "sa|sb|sc|sd|se|sg|si|sk|sl|sm|sn|so|sr|ss|st|sv|sx|sy|sz"
      "tc|td|tg|th|tj|tk|tl|tm|tn|to|tr|tt|tv|tw|tz"
      "ua|ug|us|uy|uz"
      "va|vc|ve|vg|vi|vn|vu"
      "wf|ws"
      "ye|yt"
      "za|zm|zw"
    ]
  );

  privateV4 = [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "224.0.0.0/4"
    "240.0.0.0/4"
  ];

  privateV6 = [
    "::/128"
    "::1/128"
    "fc00::/7"
    "fe80::/10"
    "ff00::/8"
  ];

  isIPv4 = s: (builtins.match "^[0-9]{1,3}(\\.[0-9]{1,3}){3}$" s) != null;

  isIPv4CIDR = s: (builtins.match "^[0-9]{1,3}(\\.[0-9]{1,3}){3}(/[0-9]{1,2})?$" s) != null;

  isIPv6 = s: (builtins.match ".*:.*:.*" s) != null && (builtins.match "^[0-9A-Fa-f:.]+$" s) != null;

  isIPv6CIDR =
    s:
    (builtins.match ".*:.*:.*" s) != null
    && (builtins.match "^[0-9A-Fa-f:.]+(/[0-9]{1,3})?$" s) != null;

  isValidAllowedIP = s: isIPv4 s || isIPv4CIDR s || isIPv6 s || isIPv6CIDR s;

  countryBlocks = pkgs.fetchFromGitHub {
    owner = "leahevy";
    repo = "country-ip-blocks";
    rev = "761a66ad605119007676cdd454af231f0a7ac3d7";
    hash = "sha256-R6zineM3CtX3lQ98HdjwiN10uYc9DKr09zX2ls8tbek=";
  };

  mkGeoSets =
    countries: setPrefix:
    pkgs.runCommand "geoip-sets-${setPrefix}" { } ''
      mkdir -p "$out"
      > "$out/v4.txt"
      > "$out/v6.txt"
      for cc in ${lib.escapeShellArgs countries}; do
        v4="${countryBlocks}/country/$cc/ipv4-aggregated.txt"
        v6="${countryBlocks}/country/$cc/ipv6-aggregated.txt"
        [ -f "$v4" ] && grep -v '^#' "$v4" >> "$out/v4.txt" || true
        [ -f "$v6" ] && grep -v '^#' "$v6" >> "$out/v6.txt" || true
      done
      {
        echo "set ${setPrefix}-v4 {"
        echo "  type ipv4_addr"
        echo "  flags interval"
        if [ -s "$out/v4.txt" ]; then
          echo "  elements = {"
          sed 's/$/,/' "$out/v4.txt"
          echo "  }"
        fi
        echo "}"
        echo "set ${setPrefix}-v6 {"
        echo "  type ipv6_addr"
        echo "  flags interval"
        if [ -s "$out/v6.txt" ]; then
          echo "  elements = {"
          sed 's/$/,/' "$out/v6.txt"
          echo "  }"
        fi
        echo "}"
      } > "$out/sets.nft"
    '';

  computeGeo =
    {
      onlyAllowCountriesFromVariables,
      allowedCountries,
      blockedCountries,
      allowedIPs,
    }:
    let
      alwaysAllowed = self.variables.allowedCountriesByGeoIP;
      effectiveAllowed = if onlyAllowCountriesFromVariables then alwaysAllowed else allowedCountries;
      effectiveBlocked = lib.filter (c: !(builtins.elem c alwaysAllowed)) blockedCountries;
      isAllowMode = onlyAllowCountriesFromVariables || effectiveAllowed != [ ];
      geoActive =
        isAllowMode || (!onlyAllowCountriesFromVariables && effectiveBlocked != [ ]) || allowedIPs != [ ];
      countries = if isAllowMode then effectiveAllowed else effectiveBlocked;
      setPrefix = if isAllowMode then "geo-allowed" else "geo-blocked";
      partitioned = lib.partition (lib.hasInfix ":") allowedIPs;
      allowedIPv4 = partitioned.wrong;
      allowedIPv6 = partitioned.right;
    in
    {
      inherit
        alwaysAllowed
        effectiveAllowed
        effectiveBlocked
        isAllowMode
        geoActive
        countries
        setPrefix
        allowedIPv4
        allowedIPv6
        ;
      geoData = mkGeoSets countries setPrefix;
    };
in
{
  name = "geo-ip";
  group = "networking";
  input = "linux";

  options = {
    enableGeoIPBlocks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply GeoIP nftables rules when countries are configured.";
    };
    enableLogging = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Log packets dropped by the GeoIP filter, or null to enable per default in local and develop mode.";
    };
    onlyAllowCountriesFromVariables = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use variables.allowedCountriesByGeoIP as the authoritative GeoIP allowlist.";
    };
    allowedCountries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Country codes to allowlist when onlyAllowCountriesFromVariables is false.";
    };
    blockedCountries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Country codes to blocklist when onlyAllowCountriesFromVariables is false.";
    };
    allowedIPs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "IP addresses or CIDRs that are always accepted before geo filtering.";
    };
  };

  module = {
    linux.system =
      {
        config,
        enableGeoIPBlocks,
        enableLogging,
        onlyAllowCountriesFromVariables,
        allowedCountries,
        blockedCountries,
        allowedIPs,
        ...
      }:
      let
        geo = computeGeo {
          inherit
            onlyAllowCountriesFromVariables
            allowedCountries
            blockedCountries
            allowedIPs
            ;
        };
        invalidAllowed = lib.filter (c: !(builtins.elem c validCodes)) geo.effectiveAllowed;
        invalidBlocked = lib.filter (c: !(builtins.elem c validCodes)) geo.effectiveBlocked;
        invalidAllowedIPs = lib.filter (ip: !(isValidAllowedIP ip)) allowedIPs;
        effectiveLogging =
          if enableLogging == null then
            !(builtins.elem config.nx.global.deploymentMode [
              "server"
              "managed"
            ])
          else
            enableLogging;
        ipOnlyMode = allowedIPs != [ ] && geo.countries == [ ];
        chainPolicy = if geo.isAllowMode || ipOnlyMode then "drop" else "accept";
        acceptOrDrop = if geo.isAllowMode then "accept" else "drop";
      in
      {
        warnings = lib.optional ipOnlyMode "geo-ip: allowedIPs is set but no countries are configured. Everything except allowedIPs and private ranges will be dropped. Possible lock-out in progress.";

        assertions = [
          {
            assertion =
              !(onlyAllowCountriesFromVariables && (allowedCountries != [ ] || blockedCountries != [ ]));
            message = "geo-ip: onlyAllowCountriesFromVariables is true, allowedCountries and blockedCountries must both be empty!";
          }
          {
            assertion = !(allowedCountries != [ ] && blockedCountries != [ ]);
            message = "geo-ip: allowedCountries and blockedCountries are mutually exclusive!";
          }
          {
            assertion = invalidAllowed == [ ];
            message = "geo-ip: unknown country codes in allowedCountries: ${lib.concatStringsSep ", " invalidAllowed}!";
          }
          {
            assertion = invalidBlocked == [ ];
            message = "geo-ip: unknown country codes in blockedCountries: ${lib.concatStringsSep ", " invalidBlocked}!";
          }
          {
            assertion = invalidAllowedIPs == [ ];
            message = "geo-ip: invalid IP addresses or CIDRs in allowedIPs: ${lib.concatStringsSep ", " invalidAllowedIPs}!";
          }
        ];

        networking.nftables.tables =
          lib.mkIf (geo.geoActive && enableGeoIPBlocks && config.networking.firewall.enable)
            {
              "geo-filter" = {
                family = "inet";
                content = ''
                  include "${geo.geoData}/sets.nft"
                  chain geo-input {
                    type filter hook input priority -90; policy ${chainPolicy};
                    iifname lo accept
                    ct state { established, related } accept
                    ip saddr { ${lib.concatStringsSep ", " privateV4} } accept
                    ip6 saddr { ${lib.concatStringsSep ", " privateV6} } accept
                    ${lib.optionalString (
                      geo.allowedIPv4 != [ ]
                    ) "ip saddr { ${lib.concatStringsSep ", " geo.allowedIPv4} } accept"}
                    ${lib.optionalString (
                      geo.allowedIPv6 != [ ]
                    ) "ip6 saddr { ${lib.concatStringsSep ", " geo.allowedIPv6} } accept"}
                    ${lib.optionalString (geo.countries != [ ]) ''
                      ip saddr @${geo.setPrefix}-v4 counter ${acceptOrDrop}
                      ip6 saddr @${geo.setPrefix}-v6 counter ${acceptOrDrop}
                    ''}
                    ${lib.optionalString effectiveLogging ''log prefix "geo-ip-drop: "''}
                    counter ${chainPolicy}
                  }
                '';
              };
            };
      };

    linux.home =
      {
        config,
        enableGeoIPBlocks,
        onlyAllowCountriesFromVariables,
        allowedCountries,
        blockedCountries,
        allowedIPs,
        ...
      }:
      let
        geo = computeGeo {
          inherit
            onlyAllowCountriesFromVariables
            allowedCountries
            blockedCountries
            allowedIPs
            ;
        };
        modeLabel = if geo.isAllowMode then "allowlist" else "blocklist";
        countriesBaked = lib.concatStringsSep " " geo.countries;

        geoTestScript = pkgs.writeText "geoblock-test.py" ''
          import sys, ipaddress
          PRIVATE_V4 = [ipaddress.ip_network(n) for n in [${
            lib.concatMapStringsSep ", " (n: "\"${n}\"") privateV4
          }]]
          PRIVATE_V6 = [ipaddress.ip_network(n) for n in [${
            lib.concatMapStringsSep ", " (n: "\"${n}\"") privateV6
          }]]
          ip_str = sys.argv[1]
          mode = "${modeLabel}"
          cidr_v4 = "${geo.geoData}/v4.txt"
          cidr_v6 = "${geo.geoData}/v6.txt"
          countries = "${countriesBaked}"
          try:
              ip = ipaddress.ip_address(ip_str)
          except ValueError:
              print(f"ERROR: '{ip_str}' is not a valid IP address")
              sys.exit(1)
          private_nets = PRIVATE_V4 if ip.version == 4 else PRIVATE_V6
          if any(ip in net for net in private_nets):
              print(f"OK: {ip_str} is a private/special-purpose address (always accepted)")
              sys.exit(0)
          allowed_ips = [ipaddress.ip_network(e, strict=False) for e in "${lib.concatStringsSep " " allowedIPs}".split() if e]
          if any(ip in net for net in allowed_ips):
              print(f"OK: {ip_str} matches an entry in allowedIPs (always accepted)")
              sys.exit(0)
          path = cidr_v4 if ip.version == 4 else cidr_v6
          try:
              with open(path) as fh:
                  cidrs = [l.strip() for l in fh if l.strip() and not l.startswith('#')]
          except FileNotFoundError:
              cidrs = []
          match = next((c for c in cidrs if ip in ipaddress.ip_network(c, strict=False)), None)
          if mode == "allowlist":
              if match:
                  print(f"OK: {ip_str} is in the allowed set (matched {match})")
              else:
                  print(f"BLOCKED: {ip_str} is NOT in the allowed set")
          else:
              if match:
                  print(f"BLOCKED: {ip_str} is in the blocked set (matched {match})")
              else:
                  print(f"OK: {ip_str} is NOT in the blocked set")
          print(f"Mode: {mode} | countries: {countries}")
        '';
      in
      lib.mkIf geo.geoActive {
        home.packages = [
          (pkgs.writeShellScriptBin "geoblock-test-ip" ''
            set -euo pipefail
            if [ $# -ne 1 ]; then
              echo "Usage: geoblock-test-ip <ip-address>"
              exit 1
            fi
            ${lib.optionalString (
              !enableGeoIPBlocks
            ) "echo \"NOTE: GeoIP blocking is currently disabled (enableGeoIPBlocks = false)\""}
            ${pkgs.python3}/bin/python3 ${geoTestScript} "$1"
          '')

          (pkgs.writeShellScriptBin "geoblock-stats" ''
            set -euo pipefail
            if ! sudo ${pkgs.nftables}/bin/nft list chain inet geo-filter geo-input 2>/dev/null | grep -q "geo-input"; then
              echo "GeoIP chain not found. Is enableGeoIPBlocks = true and the service running?"
              exit 1
            fi
            sudo ${pkgs.nftables}/bin/nft list chain inet geo-filter geo-input
          '')

          (pkgs.writeShellScriptBin "geoblock-reset-counters" ''
            set -euo pipefail
            if ! sudo ${pkgs.nftables}/bin/nft list chain inet geo-filter geo-input 2>/dev/null | grep -q "geo-input"; then
              echo "GeoIP chain not found. Is enableGeoIPBlocks = true and the service running?"
              exit 1
            fi

            handles=$(
              sudo ${pkgs.nftables}/bin/nft -a list chain inet geo-filter geo-input \
                | ${pkgs.gnused}/bin/sed -n 's/.*# handle \([0-9][0-9]*\)$/\1/p'
            )

            if [ -z "$handles" ]; then
              echo "No GeoIP rule handles found."
              exit 1
            fi

            for handle in $handles; do
              sudo ${pkgs.nftables}/bin/nft reset rule inet geo-filter geo-input handle "$handle" > /dev/null
            done

            echo "GeoIP counters reset."
            echo ""
            geoblock-stats
          '')
        ];
      };
  };
}
