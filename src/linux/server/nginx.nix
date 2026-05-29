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
      description = "Open port 443 TCP (and UDP when enableQuic is true) in the firewall";
    };
    enableQuic = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable QUIC/HTTP3 support on all vhosts";
    };
    enableTestDomain = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, serve a test page at <hostname>.<baseDomain> to verify nginx and TLS are working";
    };
  };

  module = {
    ifEnabled.linux.services.fail2ban = {
      linux.system = config: {
        services.fail2ban.jails.nginx-http-auth = ''
          enabled = true
          filter = nginx-http-auth
          backend = systemd
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
        enableTestDomain,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
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
          (lib.mkIf enableTestDomain {
            assertion =
              domain != null
              && config.nx.linux.security.letsencrypt.enable
              && config.nx.linux.security.letsencrypt.dnsCerts ? ${domain};
            message = "linux.server.nginx: enableTestDomain requires letsencrypt to be configured with a cert for '${
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
              listen 443 ssl default_server;
              ssl_reject_handshake on;
            }
          '';
        };

        users.users.nginx.extraGroups = [ "acme" ];

        networking.firewall = lib.mkIf (openFirewall && config.nx.linux.networking.firewall.enable) {
          allowedTCPPorts = [ 443 ];
          allowedUDPPorts = lib.mkIf enableQuic [ 443 ];
        };

        services.nginx.virtualHosts =
          lib.mkIf
            (
              enableTestDomain
              && domain != null
              && config.nx.linux.security.letsencrypt.enable
              && config.nx.linux.security.letsencrypt.dnsCerts ? ${domain}
            )
            {
              "${self.host.hostname}.${domain}" = lib.mkDefault {
                onlySSL = true;
                useACMEHost = domain;
                quic = enableQuic;
                http3 = enableQuic;
                locations."/" = {
                  return = "200 'nginx ok'";
                  extraConfig = "add_header Content-Type text/plain;";
                };
              };
            };
      };
  };
}
