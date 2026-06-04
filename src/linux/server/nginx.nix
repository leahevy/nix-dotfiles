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
  name = "nginx";

  group = "server";
  input = "linux";

  options = {
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open ports 80 and 443 TCP (and UDP 443 when enableQuic is true) in the firewall.";
    };
    enableQuic = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable QUIC/HTTP3 support on all vhosts.";
    };
    subdomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Subdomain under baseDomain for the status page vhost, defaulting to the hostname when null.";
    };
    enableTestDomain = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Serve a minimal status page at the configured subdomain under baseDomain.";
    };
    serverOwnsBaseDomain = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, add a redirect vhost at baseDomain that forwards to the configured subdomain vhost.";
    };
  };

  module = {
    ifEnabled.linux.server.healthchecks.enabled = config: {
      nx.linux.server.healthchecks.requireServicesUp = [ "nginx.service" ];
    };

    ifEnabled.linux.services.fail2ban = {
      linux.system = config: {
        services.fail2ban.jails.nginx-http-auth = ''
          enabled = true
          filter = nginx-http-auth
          backend = systemd
          journalmatch = _SYSTEMD_UNIT=nginx.service
          maxretry = 5
          findtime = 600
          bantime = 3600
        '';
      };
    };

    linux.system =
      {
        config,
        openFirewall,
        enableQuic,
        subdomain,
        enableTestDomain,
        serverOwnsBaseDomain,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        effectiveSubdomain = if subdomain == null then self.host.hostname else subdomain;
        uncoveredVhosts = lib.filterAttrs (
          name: vh:
          let
            acmeHost = vh.useACMEHost;
            cert = config.security.acme.certs.${acmeHost} or null;
            certDomains = if cert != null then cert.extraDomainNames else [ ];
          in
          !(
            cert != null
            && (name == acmeHost || lib.elem name certDomains || lib.elem "*.${acmeHost}" certDomains)
          )
        ) (lib.filterAttrs (_: vh: vh.useACMEHost != null) config.services.nginx.virtualHosts);
      in
      {
        assertions = [
          {
            assertion = config.nx.linux.security.letsencrypt.enable;
            message = "linux.server.nginx requires linux.security.letsencrypt to be enabled!";
          }
          {
            assertion = domain != null;
            message = "linux.server.nginx requires host.remote.baseDomain to be set!";
          }
          {
            assertion = uncoveredVhosts == { };
            message = "linux.server.nginx: virtual hosts not covered by their ACME cert: ${lib.concatStringsSep ", " (lib.attrNames uncoveredVhosts)}!";
          }
          (lib.mkIf (enableTestDomain || serverOwnsBaseDomain) {
            assertion =
              domain != null
              && config.nx.linux.security.letsencrypt.enable
              && config.nx.linux.security.letsencrypt.dnsCerts ? ${domain};
            message = "linux.server.nginx: enableTestDomain/serverOwnsBaseDomain requires letsencrypt to be configured with a cert for '${
              if domain != null then domain else "null"
            }'!";
          })
        ];

        services.nginx = {
          enable = true;
          enableQuicBPF = enableQuic;
          recommendedProxySettings = true;
          recommendedTlsSettings = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          commonHttpConfig = "access_log syslog:server=unix:/dev/log combined;";
          appendHttpConfig = ''
            server {
              listen 0.0.0.0:80 default_server;
              listen [::0]:80 default_server;
              server_name _;
              return 301 https://$host$request_uri;
            }
            server {
              listen 0.0.0.0:443 ssl default_server;
              listen [::0]:443 ssl default_server;
              ${lib.optionalString enableQuic ''
                listen 0.0.0.0:443 quic default_server;
                listen [::0]:443 quic default_server;
              ''}
              ssl_reject_handshake on;
            }
          '';
        };

        users.users.nginx.extraGroups = [ "acme" ];

        networking.firewall = lib.mkIf (openFirewall && config.nx.linux.networking.firewall.enable) {
          allowedTCPPorts = [
            80
            443
          ];
          allowedUDPPorts = lib.mkIf enableQuic [ 443 ];
        };

        services.nginx.virtualHosts = lib.mkMerge [
          (lib.mkIf
            (
              enableTestDomain
              && domain != null
              && config.nx.linux.security.letsencrypt.enable
              && config.nx.linux.security.letsencrypt.dnsCerts ? ${domain}
            )
            {
              "${effectiveSubdomain}.${domain}" = lib.mkDefault {
                onlySSL = true;
                useACMEHost = domain;
                quic = enableQuic;
                http3 = enableQuic;
                locations."/" = {
                  return = "200 '${effectiveSubdomain} ok'";
                  extraConfig = "add_header Content-Type text/plain;";
                };
              };
            }
          )
          (lib.mkIf
            (
              serverOwnsBaseDomain
              && domain != null
              && config.nx.linux.security.letsencrypt.enable
              && config.nx.linux.security.letsencrypt.dnsCerts ? ${domain}
            )
            {
              "${domain}" = {
                onlySSL = true;
                useACMEHost = domain;
                quic = enableQuic;
                http3 = enableQuic;
                locations."/" = {
                  return = "301 https://${effectiveSubdomain}.${domain}$request_uri";
                };
              };
            }
          )
        ];
      };
  };
}
