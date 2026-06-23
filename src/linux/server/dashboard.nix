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

    columnsPerGroup = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Number of service cards shown per row within each group.";
    };

    mainGroupName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Display name for the main services group, overriding the default of 'Services' on the full dashboard and 'Home' on the restricted dashboard.";
    };

    squareCorners = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Remove all border-radius from every element on the page.";
    };

    hideSearchPlaceholder = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Hide the static placeholder text in the search bar.";
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

    showSearchSuggestions = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show search suggestions when a custom searchURL is set.";
    };

    searchURL = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override the search widget URL, taking precedence over useStartpageAsSearchEngine when set.";
    };

    suggestionURL = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Autocomplete suggestions endpoint URL passed to the search widget when showSearchSuggestions is true.";
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
                "services-internal"
                "health"
                "admin"
                "details"
              ];
              default = "services";
              description = "Dashboard group this entry is placed in: services for public user-facing apps, services-internal for apps shown on the Home tab only to trusted clients, admin for internal tooling, health for admin status widgets, and details for individual check cards shown on a separate tab.";
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
                "links"
                "links-admin"
                "links-details"
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

    homepageSecretEnvFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variable names mapped to secret file paths whose contents are written to the Homepage environment file.";
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

    addDefaultLinks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add a default set of bookmark links to the links group.";
    };

    gatewayIP = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "IP address of the main network gateway, added as a server bookmark when set.";
    };

    enableThemeColorOverwrite = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically set the dashboard accent color and background to match the active color theme when one is enabled.";
    };

    localBackgroundFileMapping = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Map of color theme names to background image filenames in the profile files directory, used when that theme is active and enableThemeColorOverwrite is true.";
    };
  };

  module = {
    ifEnabled.linux.server.auth = {
      enabled =
        config:
        let
          exposedService = self.host.remote.exposedServices.dashboard;
          nginxSubdomain = config.nx.linux.server.nginx.subdomain;
          effectiveSubdomain =
            if config.nx.linux.server.dashboard.hostAtNginxSubdomain then
              (if nginxSubdomain == null then self.host.hostname else nginxSubdomain)
            else
              config.nx.linux.server.dashboard.subdomain;
        in
        lib.mkIf (config.nx.linux.server.auth.enableOAuthProxy && exposedService != false) {
          nx.linux.server.auth.proxyProtectedVhosts = [ effectiveSubdomain ];
        };
    };

    ifEnabled.linux.server.healthchecks.enabled = config: {
      nx.linux.server.healthchecks.requireServicesUp = [
        "homepage-dashboard.service"
        "homepage-dashboard-restricted.service"
      ];
    };

    enabled = config: {
      nx.linux.server.dashboard.bookmarks = lib.mkIf config.nx.linux.server.dashboard.addDefaultLinks (
        lib.mkBefore [
          {
            name = "Google";
            href = "https://www.google.de";
            icon = "google";
            group = "links";
          }
          {
            name = "Startpage";
            href = "https://www.startpage.com";
            icon = "searxng";
            group = "links";
          }
          {
            name = "DuckDuckGo";
            href = "https://duckduckgo.com";
            icon = "duckduckgo";
            group = "links";
          }
          {
            name = "YouTube";
            href = "https://www.youtube.com";
            icon = "youtube";
            group = "links";
          }
          {
            name = "Amazon";
            href = "https://www.amazon.de";
            icon = "amazon";
            group = "links";
          }
        ]
      );
      nx.packages.extra = [ pkgs.homepage-dashboard ];
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
        homepageSecretEnvFiles,
        columnsPerGroup,
        squareCorners,
        hideSearchPlaceholder,
        enableSearchWidget,
        useStartpageAsSearchEngine,
        searchOpenInNewTab,
        showSearchSuggestions,
        searchURL,
        suggestionURL,
        addNixRepoBookmarks,
        gatewayIP,
        enableThemeColorOverwrite,
        localBackgroundFileMapping,
        mainGroupName,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        hostname = self.host.hostname;

        themeColorMap = {
          blue = "blue";
          cyan = "cyan";
          green = "green";
          magenta = "fuchsia";
          orange = "orange";
          purple = "purple";
          red = "red";
          white = "slate";
          yellow = "yellow";
        };

        activeTheme = lib.findFirst (name: config.nx.themes.themes.${name}.enable) null (
          lib.attrNames themeColorMap
        );

        effectiveColor =
          if enableThemeColorOverwrite && activeTheme != null then themeColorMap.${activeTheme} else color;

        effectiveLocalBackgroundFile =
          if enableThemeColorOverwrite && activeTheme != null then
            localBackgroundFileMapping.${activeTheme} or localBackgroundFile
          else
            localBackgroundFile;
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

        resolveIcon =
          icon:
          if icon == null || lib.hasPrefix "http" icon || lib.hasPrefix "/" icon then
            icon
          else
            "/icons/${icon}.png";
        mkServiceEntry = svc: {
          "${svc.name}" = {
            inherit (svc) href;
          }
          // lib.optionalAttrs svc.enableSiteMonitor { siteMonitor = svc.href; }
          // lib.optionalAttrs (svc.icon != null) { icon = resolveIcon svc.icon; }
          // lib.optionalAttrs (svc.description != "") { inherit (svc) description; }
          // lib.optionalAttrs (svc.widgets != [ ]) { inherit (svc) widgets; };
        };

        servicesByGroup = lib.groupBy (svc: svc.group) services;

        mainServiceEntries = map mkServiceEntry (servicesByGroup.services or [ ]);
        internalServiceEntries = map mkServiceEntry (servicesByGroup."services-internal" or [ ]);
        adminServiceEntries = map mkServiceEntry (servicesByGroup.admin or [ ]);
        healthServiceEntries = map mkServiceEntry (servicesByGroup.health or [ ]);
        detailsServiceEntries = map mkServiceEntry (servicesByGroup.details or [ ]);

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
            icon = resolveIcon (if svc.iconUrl != null then svc.iconUrl else svc.iconName);
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

        externalServiceEntries = additionalServiceEntries;
        homeServiceEntries = mainServiceEntries ++ externalServiceEntries;
        fullHomeServiceEntries = homeServiceEntries ++ internalServiceEntries;

        backgroundAttr =
          if effectiveLocalBackgroundFile != null then
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
          if searchURL != null then
            {
              search = {
                provider = "custom";
                url = searchURL;
                target = if searchOpenInNewTab then "_blank" else "_self";
                showSearchSuggestions = showSearchSuggestions;
                focus = true;
              }
              // lib.optionalAttrs (suggestionURL != null) { suggestionUrl = suggestionURL; };
            }
          else if useStartpageAsSearchEngine then
            {
              search = {
                provider = "custom";
                url = "https://www.startpage.com/sp/search?query=";
                target = if searchOpenInNewTab then "_blank" else "_self";
                showSearchSuggestions = showSearchSuggestions;
                focus = true;
              }
              // lib.optionalAttrs (suggestionURL != null) { suggestionUrl = suggestionURL; };
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

        hasDetailsTab = detailsServiceEntries != [ ];
        generatedLayout =
          lib.optional (fullHomeServiceEntries != [ ]) {
            ${effectiveMainGroupName} = {
              style = "row";
              columns = columnsPerGroup;
              tab = "Home";
            };
          }
          ++ lib.optional (linksBookmarkEntries != [ ]) {
            Links = {
              style = "row";
              columns = columnsPerGroup * 2;
              tab = "Home";
            };
          }
          ++ lib.optional (adminServiceEntries != [ ]) {
            Administration = {
              tab = "Admin";
            };
          }
          ++ lib.optional (healthServiceEntries != [ ]) {
            Health = {
              tab = "Admin";
            };
          }
          ++ lib.optional (adminLinksBookmarkEntries != [ ]) {
            "Links (Admin)" = {
              style = "row";
              columns = columnsPerGroup * 2;
              tab = "Admin";
            };
          }
          ++ lib.optional (detailsLinksBookmarkEntries != [ ]) {
            "Links (Details)" = {
              tab = "Details";
            };
          }
          ++ lib.optional hasDetailsTab {
            Details = {
              style = "row";
              columns = columnsPerGroup * 2;
              tab = "Details";
            };
          };

        generatedSettings = lib.recursiveUpdate (
          {
            title = if title != null then title else hostname;
            inherit
              theme
              headerStyle
              statusStyle
              showStats
              useEqualHeights
              language
              ;
            color = effectiveColor;
            hideVersion = true;
            disableUpdateCheck = true;
            disableCollapse = true;
            maxServiceGroupColumns = columnsPerGroup * 2;
            maxBookmarkGroupColumns = columnsPerGroup * 2;
          }
          // lib.optionalAttrs (description != "") { description = description; }
          // lib.optionalAttrs (backgroundAttr != null) { background = backgroundAttr; }
          // lib.optionalAttrs (faviconAttr != null) { favicon = faviconAttr; }
          // {
            layout = generatedLayout;
          }
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
            ".container {\n  max-width: ${toString (columnsPerGroup * 800)}px;\n}"
            ''
              #tabs ul {
                background-color: rgb(var(--color-200) / 0.4);
              }
              .dark #tabs ul {
                background-color: rgba(255, 255, 255, 0.12);
              }
              #tabs button[aria-selected="true"] {
                background-color: rgb(var(--color-400) / 0.3);
              }
              .dark #tabs button[aria-selected="true"] {
                background-color: rgba(255, 255, 255, 0.16);
              }
              #tabs button:hover:not([aria-selected="true"]) {
                background-color: rgb(var(--color-200) / 0.15);
              }
              .dark #tabs button:hover:not([aria-selected="true"]) {
                background-color: rgba(255, 255, 255, 0.04);
              }''
            ''
              li.service .service-card,
              li.bookmark a {
                transition: transform 160ms ease;
                transform-origin: center center;
              }
              li.service:hover .service-card,
              li.bookmark:hover a {
                transform: scale(1.018);
              }''
            (lib.optionalString (backgroundBlur == null && backgroundAttr != null) ''
              .bookmark a,
              .service-card {
                background-color: rgb(var(--color-100) / 0.65);
              }
              .dark .bookmark a,
              .dark .service-card,
              .dark #page_wrapper input[type="text"] {
                background-color: ${
                  if effectiveColor == "neutral" then
                    "rgb(var(--color-700) / 0.4)"
                  else
                    "color-mix(in srgb, rgb(var(--color-700)) 25%, rgb(20 20 20 / 0.75))"
                };
              }'')
            (lib.optionalString
              (backgroundBlur == null && backgroundAttr != null && effectiveColor != "neutral")
              ''
                #page_wrapper::before {
                  content: "";
                  position: fixed;
                  inset: 0;
                  background: rgba(0, 0, 0, 0.4);
                  z-index: 0;
                  pointer-events: none;
                }
                #inner_wrapper {
                  position: relative;
                  z-index: 1;
                }
                .dark .bookmark-group-name,
                .dark .service-group-name {
                  text-shadow: 0 1px 6px rgba(0, 0, 0, 0.9);
                }
                .dark .information-widget-resources {
                  text-shadow: 0 1px 8px rgba(0, 0, 0, 1), 0 0 12px rgba(0, 0, 0, 0.9);
                }''
            )
            (lib.optionalString squareCorners "* { border-radius: 0 !important; }")
            (lib.optionalString hideSearchPlaceholder ''
              .information-widget-search input::placeholder {
                color: transparent !important;
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
            group = "links-admin";
          };

        autoBookmarks = lib.optional (gatewayIP != null) {
          name = "Gateway";
          icon = "openwrt";
          href = "http://${gatewayIP}";
          group = "links-admin";
        };

        repoBookmarks = lib.optionals addNixRepoBookmarks (
          mkRepoBookmark "Nix Core" (self.variables.coreRepoURL or null)
          ++ mkRepoBookmark "Nix Config" (self.variables.configRepoURL or null)
        );

        allBookmarks = autoBookmarks ++ bookmarks ++ repoBookmarks;
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
              inherit (b) href;
              icon = resolveIcon b.icon;
              description = b.description or "";
              abbr = mkBookmarkAbbr b.name;
            }
          ];
        };

        linksBookmarkEntries = map mkBookmarkEntry (bookmarksByGroup.links or [ ]);
        adminLinksBookmarkEntries = map mkBookmarkEntry (bookmarksByGroup.links-admin or [ ]);
        detailsLinksBookmarkEntries = map mkBookmarkEntry (bookmarksByGroup.links-details or [ ]);

        generatedBookmarks =
          lib.optional (linksBookmarkEntries != [ ]) { Links = linksBookmarkEntries; }
          ++ lib.optional (adminLinksBookmarkEntries != [ ]) { "Links (Admin)" = adminLinksBookmarkEntries; }
          ++ lib.optional (detailsLinksBookmarkEntries != [ ]) {
            "Links (Details)" = detailsLinksBookmarkEntries;
          };

        effectiveMainGroupName = if mainGroupName != null then mainGroupName else "Services";
        effectiveRestrictedGroupName = if mainGroupName != null then mainGroupName else "Home";
        restrictedListenPort = listenPort + 1;
        yamlFormat = pkgs.formats.yaml { };

        restrictedLayout =
          lib.optional (homeServiceEntries != [ ]) {
            ${effectiveRestrictedGroupName} = {
              style = "row";
              columns = columnsPerGroup;
            };
          }
          ++ lib.optional (linksBookmarkEntries != [ ]) {
            Links = {
              style = "row";
              columns = columnsPerGroup * 2;
            };
          };

        restrictedSettings = generatedSettings // {
          showStats = false;
          layout = restrictedLayout;
        };

        restrictedServices = lib.optional (homeServiceEntries != [ ]) {
          ${effectiveRestrictedGroupName} = homeServiceEntries;
        };

        restrictedBookmarks = lib.optional (linksBookmarkEntries != [ ]) { Links = linksBookmarkEntries; };

        baseVhost =
          lib.recursiveUpdate
            {
              onlySSL = true;
              useACMEHost = domain;
              quic = enableQuic;
              http3 = enableQuic;
              locations."/" = {
                proxyPass = "http://$dashboard_upstream";
                proxyWebsockets = true;
                return = null;
                extraConfig = "";
              };
            }
            {
              locations =
                lib.optionalAttrs (effectiveLocalBackgroundFile != null) {
                  "= /dashboard-bg" = {
                    alias = "${self.profile.filesPath effectiveLocalBackgroundFile}";
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
            assertion = !showSearchSuggestions || suggestionURL != null;
            message = "linux.server.dashboard: showSearchSuggestions requires suggestionURL to be set!";
          }
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
          environmentFiles = [ "/run/homepage-dashboard-env/env" ];
          settings = generatedSettings;
          bookmarks = generatedBookmarks;
          services =
            lib.optional (fullHomeServiceEntries != [ ]) { ${effectiveMainGroupName} = fullHomeServiceEntries; }
            ++ lib.optional (adminServiceEntries != [ ]) { Administration = adminServiceEntries; }
            ++ lib.optional (healthServiceEntries != [ ]) { Health = healthServiceEntries; }
            ++ lib.optional (detailsServiceEntries != [ ]) { Details = detailsServiceEntries; };
          widgets = autoWidgets ++ widgets;
          customCSS = generatedCSS;
        };

        systemd.services.homepage-dashboard.restartTriggers = [
          config.systemd.services.homepage-dashboard-env.serviceConfig.ExecStart
          (builtins.toJSON generatedSettings)
        ];

        systemd.services.homepage-dashboard-env = {
          description = "Prepare homepage-dashboard environment";
          before = [
            "homepage-dashboard.service"
            "homepage-dashboard-restricted.service"
          ];
          wantedBy = [
            "homepage-dashboard.service"
            "homepage-dashboard-restricted.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "homepage-dashboard-env";
            RuntimeDirectoryMode = "0700";
            ExecStart = toString (
              pkgs.writeShellScript "homepage-prepare-env" ''
                umask 077
                ${pkgs.coreutils}/bin/rm -f /run/homepage-dashboard-env/env
                ${pkgs.coreutils}/bin/touch /run/homepage-dashboard-env/env
                ${lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (name: path: ''
                    {
                      printf '%s=' ${lib.escapeShellArg name}
                      ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg path}
                      printf '\n'
                    } >> /run/homepage-dashboard-env/env
                  '') homepageSecretEnvFiles
                )}
              ''
            );
          };
        };

        services.nginx.commonHttpConfig = ''
          map $nx_is_internal $dashboard_upstream {
            1 127.0.0.1:${toString listenPort};
            default 127.0.0.1:${toString restrictedListenPort};
          }
        '';

        environment.etc = {
          "homepage-dashboard-restricted/custom.css".text = generatedCSS;
          "homepage-dashboard-restricted/custom.js".text = "";
          "homepage-dashboard-restricted/bookmarks.yaml".source =
            yamlFormat.generate "bookmarks-restricted.yaml" restrictedBookmarks;
          "homepage-dashboard-restricted/docker.yaml".source =
            yamlFormat.generate "docker-restricted.yaml"
              { };
          "homepage-dashboard-restricted/kubernetes.yaml".source =
            yamlFormat.generate "kubernetes-restricted.yaml"
              { };
          "homepage-dashboard-restricted/services.yaml".source =
            yamlFormat.generate "services-restricted.yaml" restrictedServices;
          "homepage-dashboard-restricted/settings.yaml".source =
            yamlFormat.generate "settings-restricted.yaml" restrictedSettings;
          "homepage-dashboard-restricted/widgets.yaml".source =
            yamlFormat.generate "widgets-restricted.yaml" searchWidget;
          "homepage-dashboard-restricted/proxmox.yaml".source =
            yamlFormat.generate "proxmox-restricted.yaml"
              { };
        };

        systemd.services.homepage-dashboard-restricted = {
          description = "Homepage Dashboard (Restricted)";
          after = [
            "network.target"
            "homepage-dashboard-env.service"
          ];
          wants = [ "homepage-dashboard-env.service" ];
          wantedBy = [ "multi-user.target" ];
          inherit (config.systemd.services.homepage-dashboard) preStart enableStrictShellChecks;
          restartTriggers = [
            config.systemd.services.homepage-dashboard-env.serviceConfig.ExecStart
            (builtins.toJSON restrictedSettings)
          ];
          environment = config.systemd.services.homepage-dashboard.environment // {
            HOMEPAGE_CONFIG_DIR = "/etc/homepage-dashboard-restricted";
            NIXPKGS_HOMEPAGE_CACHE_DIR = "/var/cache/homepage-dashboard-restricted";
            PORT = toString restrictedListenPort;
          };
          serviceConfig = config.systemd.services.homepage-dashboard.serviceConfig // {
            StateDirectory = "homepage-dashboard-restricted";
            CacheDirectory = "homepage-dashboard-restricted";
          };
        };

        services.nginx.virtualHosts."${effectiveSubdomain}.${domain}" = baseVhost;
      };
  };
}
