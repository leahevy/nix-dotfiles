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
  name = "paperless-ngx";
  description = "Paperless-ngx document management service";

  group = "server";
  input = "linux";

  submodules = {
    linux.server = [ "postgresql" ];
  };

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "paperless";
      description = "Subdomain under baseDomain where paperless is served.";
    };

    ocrLanguage = lib.mkOption {
      type = lib.types.str;
      default = "deu+eng";
      description = "Tesseract OCR language codes used for document processing.";
    };

    paperlessDataBasePath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/paperless-ngx-data";
      description = "Base directory from which all paperless data subdirectories are derived.";
    };

    importPublic = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether all system users can write to the import directory.";
    };

    enableTika = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Apache Tika for Office document text extraction.";
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Username for the paperless superuser account.";
    };
  };

  module = {
    enabled = config: {
      nx.linux.server.postgresql.connectionSlots = [ 10 ];
    };

    linux.system =
      {
        config,
        subdomain,
        ocrLanguage,
        paperlessDataBasePath,
        importPublic,
        enableTika,
        adminUser,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        basePath = paperlessDataBasePath;
      in
      {
        assertions = [
          {
            assertion = config.nx.linux.security.letsencrypt.enable;
            message = "linux.server.paperless-ngx requires linux.security.letsencrypt to be enabled!";
          }
          {
            assertion = domain != null;
            message = "linux.server.paperless-ngx requires host.remote.baseDomain to be set!";
          }
        ];

        environment.persistence."${self.persist}" = {
          directories = [ basePath ];
        };

        sops.secrets."${self.host.hostname}-paperless-admin-pass" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "paperless-admin-pass";
          owner = "paperless";
          group = "paperless";
          mode = "0400";
        };

        services.paperless = {
          enable = true;
          domain = if domain != null then "${subdomain}.${domain}" else null;
          database.createLocally = true;
          dataDir = "${basePath}/data";
          mediaDir = "${basePath}/media";
          consumptionDir = "${basePath}/import";
          consumptionDirIsPublic = importPublic;
          configureTika = enableTika;
          passwordFile = config.sops.secrets."${self.host.hostname}-paperless-admin-pass".path;
          exporter.directory = "${basePath}/export";
          settings = {
            PAPERLESS_OCR_LANGUAGE = ocrLanguage;
            PAPERLESS_ADMIN_USER = adminUser;
            PAPERLESS_USE_X_FORWARD_HOST = true;
            PAPERLESS_PROXY_SSL_HEADER = [
              "HTTP_X_FORWARDED_PROTO"
              "https"
            ];
          };
        };
      };

    ifEnabled.linux.server.nginx = {
      linux.system =
        { config, subdomain, ... }:
        let
          domain = self.host.remote.baseDomain;
        in
        {
          services.nginx.virtualHosts."${subdomain}.${domain}" = {
            useACMEHost = domain;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:28981";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                client_max_body_size 50m;
              '';
            };
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "paperless.service" ];
      };
    };
  };
}
