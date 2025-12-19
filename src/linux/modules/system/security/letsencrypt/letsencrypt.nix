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
  name = "letsencrypt";

  group = "security";
  input = "linux";
  namespace = "system";

  settings = {
    dnsCerts = { };
    extraConfigDefaults = { };
  };

  configuration =
    context@{ config, options, ... }:
    {
      environment.persistence."${self.persist}" = {
        directories = [
          "/var/lib/acme"
        ];
      };

      sops.secrets."letsencrypt-dns" = lib.mkIf (self.settings.dnsCerts != { }) {
        format = "binary";
        sopsFile = self.config.secretsPath "letsencrypt-dns";
        mode = "0400";
        owner = "acme";
        group = "acme";
      };

      security.acme = lib.mkIf (self.settings.dnsCerts != { }) {
        acceptTerms = true;

        defaults = {
          email = self.user.email;
          environmentFile = config.sops.secrets."letsencrypt-dns".path;
        };

        certs = lib.mapAttrs (
          domain: certConfig:
          self.settings.extraConfigDefaults
          // {
            dnsProvider = certConfig.provider;
            group = certConfig.group or "acme";
          }
          // (certConfig.extraConfig or { })
        ) self.settings.dnsCerts;
      };
    };
}
