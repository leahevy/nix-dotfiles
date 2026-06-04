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
  name = "dashboard";
  description = "Homepage dashboard";

  group = "server";
  input = "linux";

  submodules = {
    linux = {
      server = {
        nginx = true;
      };
    };
  };

  options = {
    hostAtNginxSubdomain = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "When true, the dashboard is served at the nginx module subdomain and overrides the status page vhost.";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "dashboard";
      description = "Subdomain under baseDomain used when hostAtNginxSubdomain is false.";
    };

    title = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Page title shown in the browser tab, defaulting to the hostname when null.";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Short description shown in the page header.";
    };

    theme = lib.mkOption {
      type = lib.types.enum [
        "dark"
        "light"
      ];
      default = "dark";
      description = "Dashboard color theme.";
    };

    color = lib.mkOption {
      type = lib.types.str;
      default = "cyan";
      description = "Dashboard accent color name.";
    };

    backgroundURL = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Remote URL for a background image, used when localBackgroundFile is not set.";
    };

    faviconURL = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Remote URL for a favicon image, used when localFaviconFile is not set.";
    };

    localFaviconFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Filename of a favicon image in the profile files directory, served locally via nginx when set.";
    };

    backgroundOpacity = lib.mkOption {
      type = lib.types.ints.between 0 100;
      default = 10;
      description = "Background image opacity as a percentage from 0 to 100.";
    };

    localBackgroundFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Filename of a background image in the profile files directory, served locally via nginx when set.";
    };

    headerStyle = lib.mkOption {
      type = lib.types.str;
      default = "clean";
      description = "Header style: clean, underlined, boxed, or boxedWidgets.";
    };

    statusStyle = lib.mkOption {
      type = lib.types.str;
      default = "dot";
      description = "Service status indicator style: dot, basic, or none.";
    };

    showStats = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show system resource statistics in the header.";
    };

    useEqualHeights = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Force all service cards to equal height.";
    };

    language = lib.mkOption {
      type = lib.types.str;
      default = "en";
      description = "Interface language code.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Local port the homepage-dashboard service binds to.";
    };

    fontFamily = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "monospace";
      description = "CSS font-family for the page body, or null to leave the browser default.";
    };

    fontSize = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "12px";
      description = "CSS font-size for the page body, or null to leave the browser default.";
    };

    bookmarks = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Bookmark groups in Homepage bookmarks YAML format.";
    };

    widgets = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Additional Homepage widget definitions merged with auto-generated widgets.";
    };

    customCSS = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Custom CSS appended after the auto-generated font and icon style rules.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Attribute set deep-merged into the generated settings.yaml as a final override.";
    };

    logoURL = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Remote URL for a logo image shown in the page header, used when localLogoFile is not set.";
    };

    localLogoFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Filename of a logo image in the profile files directory, served locally via nginx when set.";
    };

    addResourcesWidget = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add a system resources widget showing CPU, memory, temperature, uptime, and disk usage.";
    };

    additionalResourcesDiskLocations = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra disk mount paths shown in the resources widget in addition to the root filesystem.";
    };

    dockerIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Docker container status in the dashboard. Also requires virtualisation.docker.enable to be true.";
    };
  };

  module = {
    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "homepage-dashboard.service" ];
      };
      linux.system = config: {
        systemd.services.homepage-dashboard-env = {
          description = "Prepare homepage-dashboard environment";
          before = [ "homepage-dashboard.service" ];
          wantedBy = [ "homepage-dashboard.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "homepage-dashboard-env";
            RuntimeDirectoryMode = "0700";
            ExecStart = toString (
              pkgs.writeShellScript "homepage-prepare-env" ''
                umask 077
                printf 'HOMEPAGE_VAR_HEALTHCHECKS_KEY=%s\n' \
                  "$(${pkgs.coreutils}/bin/cat ${
                    config.sops.secrets."${self.host.hostname}-healthchecks-readonly-api-key".path
                  })" \
                  > /run/homepage-dashboard-env/env
              ''
            );
          };
        };
        services.homepage-dashboard.environmentFile = "/run/homepage-dashboard-env/env";
        services.homepage-dashboard.widgets = [
          {
            healthchecks = {
              url = config.nx.linux.server.healthchecks.healthchecksBaseUrl;
              key = "{{HOMEPAGE_VAR_HEALTHCHECKS_KEY}}";
            };
          }
        ];
      };
    };

    when = {
      option.dockerIntegration = true;
      condition = config: config.virtualisation.docker.enable;
      do.linux.system = config: {
        systemd.services.homepage-dashboard.serviceConfig.SupplementaryGroups = [ "docker" ];
        services.homepage-dashboard.docker = {
          local.socketPath = "/var/run/docker.sock";
        };
      };
    };

    linux.system =
      {
        config,
        hostAtNginxSubdomain,
        subdomain,
        title,
        description,
        theme,
        color,
        backgroundURL,
        backgroundOpacity,
        localBackgroundFile,
        faviconURL,
        localFaviconFile,
        logoURL,
        localLogoFile,
        addResourcesWidget,
        additionalResourcesDiskLocations,
        headerStyle,
        statusStyle,
        showStats,
        useEqualHeights,
        language,
        listenPort,
        fontFamily,
        fontSize,
        bookmarks,
        widgets,
        customCSS,
        extraSettings,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        hostname = self.host.hostname;
        nginxSubdomain = config.nx.linux.server.nginx.subdomain;
        enableQuic = config.nx.linux.server.nginx.enableQuic;

        effectiveSubdomain =
          if hostAtNginxSubdomain then
            (if nginxSubdomain == null then hostname else nginxSubdomain)
          else
            subdomain;

        activeExposedServices = lib.filterAttrs (_: v: v != false) (
          builtins.removeAttrs self.host.remote.exposedServices [ "additionalServices" ]
        );

        knownNames = {
          paperless-ngx = "Paperless";
          syncthing = "Syncthing";
        };

        exposedServiceEntries = lib.mapAttrsToList (
          key: val:
          let
            svcSubdomain = if builtins.isString val then val else key;
            displayName = knownNames.${key} or key;
          in
          {
            "${displayName}" = {
              href = "https://${svcSubdomain}.${domain}";
            };
          }
        ) activeExposedServices;

        additionalServiceEntries = lib.mapAttrsToList (
          key: svc:
          let
            displayName = if svc.name != null then svc.name else key;
            href =
              if svc.url != null then
                svc.url
              else if svc.subdomain != null then
                "https://${svc.subdomain}.${domain}"
              else
                "https://${key}.${domain}";
            icon = if svc.iconUrl != null then svc.iconUrl else svc.iconName;
          in
          {
            "${displayName}" = {
              inherit href;
            }
            // lib.optionalAttrs (icon != null) { inherit icon; }
            // lib.optionalAttrs (svc.description != "") { description = svc.description; };
          }
        ) self.host.remote.exposedServices.additionalServices;

        allServiceEntries = exposedServiceEntries ++ additionalServiceEntries;

        backgroundAttr =
          if localBackgroundFile != null then
            {
              image = "/dashboard-bg";
              opacity = backgroundOpacity;
              blur = "xl";
            }
          else if backgroundURL != null then
            {
              image = backgroundURL;
              opacity = backgroundOpacity;
              blur = "xl";
            }
          else
            null;

        faviconAttr =
          if localFaviconFile != null then
            "/dashboard-favicon"
          else if faviconURL != null then
            faviconURL
          else
            null;

        logoAttr =
          if localLogoFile != null then
            "/dashboard-logo"
          else if logoURL != null then
            logoURL
          else
            null;

        autoWidgets =
          lib.optional (logoAttr != null) {
            logo = {
              icon = logoAttr;
            };
          }
          ++ lib.optional addResourcesWidget {
            resources = {
              cpu = true;
              memory = true;
              cputemp = true;
              tempmin = 0;
              tempmax = 90;
              uptime = true;
              disk = [ "/" ] ++ additionalResourcesDiskLocations;
              expanded = true;
              refresh = 1500;
            };
          };

        generatedSettings = lib.recursiveUpdate (
          {
            title = if title != null then title else hostname;
            inherit
              theme
              color
              headerStyle
              statusStyle
              showStats
              useEqualHeights
              language
              ;
            hideVersion = true;
            disableUpdateCheck = true;
            disableCollapse = true;
          }
          // lib.optionalAttrs (description != "") { description = description; }
          // lib.optionalAttrs (backgroundAttr != null) { background = backgroundAttr; }
          // lib.optionalAttrs (faviconAttr != null) { favicon = faviconAttr; }
        ) extraSettings;

        generatedCSS = lib.concatStringsSep "\n\n" (
          lib.filter (s: s != "") [
            ''
              .w-5 {
                width: 24px;
                background-color: transparent;
              }
              .h-5 {
                height: 24px;
              }''
            (lib.optionalString (fontFamily != null || fontSize != null) (
              "body {"
              + lib.optionalString (fontFamily != null) "\n  font-family: ${fontFamily};"
              + lib.optionalString (fontSize != null) "\n  font-size: ${fontSize};"
              + "\n}"
            ))
            (lib.optionalString (
              fontFamily != null
            ) ".flex-1 {\n  font-family: ${fontFamily};\n  font-size: 18px;\n}")
            customCSS
          ]
        );

        baseVhost =
          lib.recursiveUpdate
            {
              onlySSL = true;
              useACMEHost = domain;
              quic = enableQuic;
              http3 = enableQuic;
              locations."/" = {
                proxyPass = "http://127.0.0.1:${toString listenPort}";
                proxyWebsockets = true;
              };
            }
            (
              lib.optionalAttrs (localBackgroundFile != null) {
                locations."= /dashboard-bg" = {
                  alias = "${self.profile.filesPath localBackgroundFile}";
                  extraConfig = ''add_header Cache-Control "max-age=86400";'';
                };
              }
              // lib.optionalAttrs (localFaviconFile != null) {
                locations."= /dashboard-favicon" = {
                  alias = "${self.profile.filesPath localFaviconFile}";
                  extraConfig = ''add_header Cache-Control "max-age=86400";'';
                };
              }
              // lib.optionalAttrs (localLogoFile != null) {
                locations."= /dashboard-logo" = {
                  alias = "${self.profile.filesPath localLogoFile}";
                  extraConfig = ''add_header Cache-Control "max-age=86400";'';
                };
              }
            );
      in
      {
        assertions = [
          {
            assertion = domain != null;
            message = "linux.server.dashboard requires host.remote.baseDomain to be set!";
          }
        ];

        services.homepage-dashboard = {
          enable = true;
          openFirewall = false;
          package = pkgs.homepage-dashboard.override { enableLocalIcons = true; };
          listenPort = listenPort;
          allowedHosts = "${effectiveSubdomain}.${domain}";
          settings = generatedSettings;
          inherit bookmarks;
          services = lib.optional (allServiceEntries != [ ]) {
            Services = allServiceEntries;
          };
          widgets = autoWidgets ++ widgets;
          customCSS = generatedCSS;
        };

        services.nginx.virtualHosts."${effectiveSubdomain}.${domain}" =
          if hostAtNginxSubdomain then lib.mkForce baseVhost else baseVhost;
      };
  };
}
