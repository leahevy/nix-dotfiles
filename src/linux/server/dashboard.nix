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
      type = lib.types.enum [
        "white"
        "slate"
        "gray"
        "zinc"
        "neutral"
        "stone"
        "red"
        "orange"
        "amber"
        "yellow"
        "lime"
        "green"
        "emerald"
        "teal"
        "cyan"
        "sky"
        "blue"
        "indigo"
        "violet"
        "purple"
        "fuchsia"
        "pink"
        "rose"
      ];
      default = "neutral";
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

    backgroundOverlayOpacity = lib.mkOption {
      type = lib.types.ints.between 0 100;
      default = 20;
      description = "Opacity of the theme-colored overlay drawn over the background image.";
    };

    backgroundBlur = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "sm"
          "md"
          "lg"
          "xl"
          "2xl"
          "3xl"
        ]
      );
      default = null;
      description = "Backdrop blur strength applied over the background image, or null to disable blurring.";
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
      type = lib.types.nullOr lib.types.int;
      default = 18;
      description = "Font size in pixels for the page body, or null to leave the browser default.";
    };

    maxWidth = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "800px";
      description = "CSS max-width applied to the page container, or null to use the Tailwind default.";
    };

    enableSearchWidget = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add a search widget to the dashboard header.";
    };

    useStartpageAsSearchEngine = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use Startpage as the search engine when the search widget is enabled, otherwise use Google.";
    };

    searchOpenInNewTab = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open search results in a new browser tab instead of the current tab.";
    };

    services = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name for a generated dashboard service entry.";
            };

            href = lib.mkOption {
              type = lib.types.str;
              description = "URL for a generated dashboard service entry.";
            };

            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Description for a generated dashboard service entry.";
            };

            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Homepage icon name for a generated dashboard service entry.";
            };

            enableSiteMonitor = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to configure Homepage site monitoring for this generated dashboard service entry.";
            };

            widgets = lib.mkOption {
              type = lib.types.listOf lib.types.attrs;
              default = [ ];
              description = "Homepage service widget configurations for this generated dashboard service entry.";
            };

            group = lib.mkOption {
              type = lib.types.enum [
                "services"
                "health"
                "server"
                "external"
              ];
              default = "external";
              description = "Dashboard group this entry is placed in: services for main apps, server for internal tooling, external for user-added entries.";
            };
          };
        }
      );
      default = [ ];
      description = "Service entries contributed by modules and merged into the generated Homepage service groups.";
    };

    bookmarks = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name for the bookmark entry.";
            };
            href = lib.mkOption {
              type = lib.types.str;
              description = "URL the bookmark points to.";
            };
            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "linkace";
              description = "Homepage icon name for the bookmark entry.";
            };
            group = lib.mkOption {
              type = lib.types.enum [
                "maintenance"
                "links"
              ];
              default = "links";
              description = "Bookmark group this entry is placed in.";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Description shown in the bookmark card.";
            };
          };
        }
      );
      default = [ ];
      description = "Bookmark entries contributed by modules and merged into the generated bookmark groups.";
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

    addNixRepoBookmarks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add bookmarks for the nix repo URLs defined in variables.nix when they are non-empty.";
    };

    gatewayIP = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "IP address of the main network gateway, added as a server bookmark when set.";
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
        backgroundOverlayOpacity,
        backgroundBlur,
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
        services,
        bookmarks,
        widgets,
        customCSS,
        extraSettings,
        maxWidth,
        enableSearchWidget,
        useStartpageAsSearchEngine,
        searchOpenInNewTab,
        addNixRepoBookmarks,
        gatewayIP,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        hostname = self.host.hostname;
        nginxSubdomain = config.nx.linux.server.nginx.subdomain;
        enableQuic = config.nx.linux.server.nginx.enableQuic;
        exposedService = self.host.remote.exposedServices.dashboard;
        isExposed = exposedService != false;
        exposedSubdomain = if builtins.isString exposedService then exposedService else effectiveSubdomain;

        effectiveSubdomain =
          if hostAtNginxSubdomain then
            (if nginxSubdomain == null then hostname else nginxSubdomain)
          else
            subdomain;

        mkServiceEntry = svc: {
          "${svc.name}" = {
            inherit (svc) href;
          }
          // lib.optionalAttrs svc.enableSiteMonitor { siteMonitor = svc.href; }
          // lib.optionalAttrs (svc.icon != null) { inherit (svc) icon; }
          // lib.optionalAttrs (svc.description != "") { inherit (svc) description; }
          // lib.optionalAttrs (svc.widgets != [ ]) { inherit (svc) widgets; };
        };

        servicesByGroup = lib.groupBy (svc: svc.group) services;

        mainServiceEntries = map mkServiceEntry (servicesByGroup.services or [ ]);
        serverServiceEntries = map mkServiceEntry (servicesByGroup.server or [ ]);
        healthServiceEntries = map mkServiceEntry (servicesByGroup.health or [ ]);

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
            // {
              siteMonitor = href;
            }
            // lib.optionalAttrs (icon != null) { inherit icon; }
            // lib.optionalAttrs (svc.description != "") { description = svc.description; };
          }
        ) self.host.remote.exposedServices.additionalServices;

        externalServiceEntries =
          map mkServiceEntry (servicesByGroup.external or [ ]) ++ additionalServiceEntries;

        backgroundAttr =
          if localBackgroundFile != null then
            {
              image = "/dashboard-bg";
              opacity = 100 - backgroundOverlayOpacity;
            }
            // lib.optionalAttrs (backgroundBlur != null) { blur = backgroundBlur; }
          else if backgroundURL != null then
            {
              image = backgroundURL;
              opacity = 100 - backgroundOverlayOpacity;
            }
            // lib.optionalAttrs (backgroundBlur != null) { blur = backgroundBlur; }
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

        searchWidget = lib.optional enableSearchWidget (
          if useStartpageAsSearchEngine then
            {
              search = {
                provider = "custom";
                url = "https://www.startpage.com/sp/search?query=";
                target = if searchOpenInNewTab then "_blank" else "_self";
                showSearchSuggestions = false;
                focus = true;
              };
            }
          else
            {
              search = {
                provider = "google";
                target = if searchOpenInNewTab then "_blank" else "_self";
                showSearchSuggestions = true;
                focus = true;
              };
            }
        );

        autoWidgets =
          searchWidget
          ++ lib.optional (logoAttr != null) {
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
            (lib.optionalString (fontSize != null) ''
              html {
                font-size: ${toString fontSize}px;
              }
              .text-xs {
                font-size: ${toString (fontSize * 10 / 12)}px;
              }
              .text-sm {
                font-size: ${toString (fontSize * 11 / 12)}px;
              }'')
            (lib.optionalString (fontFamily != null) ''
              body, .flex-1 {
                font-family: ${fontFamily};
              }'')
            (lib.optionalString (maxWidth != null) ".container {\n  max-width: ${maxWidth};\n}")
            (lib.optionalString (backgroundBlur == null && backgroundAttr != null) ''
              .bookmark a,
              .service-card {
                background-color: rgb(var(--color-100) / 0.65);
              }
              .dark .bookmark a,
              .dark .service-card,
              .dark #page_wrapper input[type="text"] {
                background-color: ${
                  if color == "neutral" then
                    "rgb(var(--color-700) / 0.4)"
                  else
                    "color-mix(in srgb, rgb(var(--color-700)) 25%, rgb(20 20 20 / 0.75))"
                };
              }'')
            (lib.optionalString (backgroundBlur == null && backgroundAttr != null && color != "neutral") ''
              #inner_wrapper {
                background: rgba(0, 0, 0, 0.5);
              }
              .dark .bookmark-group-name,
              .dark .service-group-name {
                text-shadow: 0 1px 6px rgba(0, 0, 0, 0.9);
              }
              .dark .information-widget-resources {
                text-shadow: 0 1px 8px rgba(0, 0, 0, 1), 0 0 12px rgba(0, 0, 0, 0.9);
              }'')
            customCSS
          ]
        );

        mkRepoBookmark =
          name: url:
          lib.optional (url != null && url != "") {
            inherit name;
            href = url;
            icon = "nixos";
            group = "links";
          };

        autoBookmarks =
          lib.optional (gatewayIP != null) {
            name = "Gateway";
            icon = "openwrt";
            href = "http://${gatewayIP}";
            group = "maintenance";
          }
          ++ lib.optionals addNixRepoBookmarks (
            mkRepoBookmark "Nix Core" (self.variables.coreRepoURL or null)
            ++ mkRepoBookmark "Nix Config" (self.variables.configRepoURL or null)
          );

        allBookmarks = autoBookmarks ++ bookmarks;
        bookmarksByGroup = lib.groupBy (b: b.group) allBookmarks;

        mkBookmarkAbbr =
          name:
          let
            words = lib.splitString " " name;
            firstAlpha =
              w:
              let
                m = builtins.match "([A-Za-z]).*" w;
              in
              if m == null then "" else lib.head m;
            abbr = lib.concatStrings (map (w: lib.toUpper (firstAlpha w)) (lib.filter (w: w != "") words));
          in
          if abbr == "" then
            throw "linux.server.dashboard: could not derive abbreviation from bookmark name '${name}'"
          else
            abbr;

        mkBookmarkEntry = b: {
          "${b.name}" = [
            {
              inherit (b) href icon;
              description = b.description or "";
              abbr = mkBookmarkAbbr b.name;
            }
          ];
        };

        maintenanceBookmarkEntries = map mkBookmarkEntry (bookmarksByGroup.maintenance or [ ]);
        linksBookmarkEntries = map mkBookmarkEntry (bookmarksByGroup.links or [ ]);

        generatedBookmarks =
          lib.optional (maintenanceBookmarkEntries != [ ]) { Maintenance = maintenanceBookmarkEntries; }
          ++ lib.optional (linksBookmarkEntries != [ ]) { Links = linksBookmarkEntries; };

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
            {
              locations =
                lib.optionalAttrs (localBackgroundFile != null) {
                  "= /dashboard-bg" = {
                    alias = "${self.profile.filesPath localBackgroundFile}";
                    extraConfig = ''add_header Cache-Control "max-age=86400";'';
                  };
                }
                // lib.optionalAttrs (localFaviconFile != null) {
                  "= /dashboard-favicon" = {
                    alias = "${self.profile.filesPath localFaviconFile}";
                    extraConfig = ''add_header Cache-Control "max-age=86400";'';
                  };
                }
                // lib.optionalAttrs (localLogoFile != null) {
                  "= /dashboard-logo" = {
                    alias = "${self.profile.filesPath localLogoFile}";
                    extraConfig = ''add_header Cache-Control "max-age=86400";'';
                  };
                };
            };
      in
      {
        assertions = [
          {
            assertion = domain != null;
            message = "linux.server.dashboard requires host.remote.baseDomain to be set!";
          }
          {
            assertion =
              gatewayIP == null
              ||
                builtins.match "(10\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}|172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9]{1,3}\\.[0-9]{1,3}|192\\.168\\.[0-9]{1,3}\\.[0-9]{1,3})" gatewayIP
                != null;
            message = "linux.server.dashboard: gatewayIP must be a valid private IPv4 address (10.x.x.x, 172.16-31.x.x, or 192.168.x.x)!";
          }
          {
            assertion = !isExposed || config.nx.linux.security.letsencrypt.enable;
            message = "linux.server.dashboard requires linux.security.letsencrypt to be enabled!";
          }
          {
            assertion = exposedService == false || exposedSubdomain == effectiveSubdomain;
            message = "linux.server.dashboard: effective subdomain '${effectiveSubdomain}' does not match exposedServices.dashboard subdomain '${exposedSubdomain}'!";
          }
        ];

        services.homepage-dashboard = {
          enable = true;
          openFirewall = false;
          package = pkgs.homepage-dashboard.override { enableLocalIcons = true; };
          listenPort = listenPort;
          allowedHosts = "${effectiveSubdomain}.${domain}";
          settings = generatedSettings;
          bookmarks = generatedBookmarks;
          services =
            lib.optional (mainServiceEntries != [ ]) { Services = mainServiceEntries; }
            ++ lib.optional (serverServiceEntries != [ ]) { Server = serverServiceEntries; }
            ++ lib.optional (healthServiceEntries != [ ]) { Health = healthServiceEntries; }
            ++ lib.optional (externalServiceEntries != [ ]) { External = externalServiceEntries; };
          widgets = autoWidgets ++ widgets;
          customCSS = generatedCSS;
        };

        services.nginx.virtualHosts."${effectiveSubdomain}.${domain}" =
          if hostAtNginxSubdomain then lib.mkForce baseVhost else baseVhost;
      };
  };
}
