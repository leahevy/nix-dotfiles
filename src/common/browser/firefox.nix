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
  lockTrue = {
    Value = true;
    Status = "locked";
  };
  lockFalse = {
    Value = false;
    Status = "locked";
  };
  lockValue = v: {
    Value = v;
    Status = "locked";
  };

  capitalizeFirst =
    s: (lib.toUpper (lib.substring 0 1 s)) + (lib.substring 1 (lib.stringLength s - 1) s);

  firefoxSpecificBookmarks = {
    firefox-config = "about:config";
    firefox-policies = "about:policies";
    firefox-extensions = "about:addons";
  };

  esc =
    s:
    builtins.replaceStrings
      [
        "&"
        "<"
        ">"
        "\""
      ]
      [
        "&amp;"
        "&lt;"
        "&gt;"
        "&quot;"
      ]
      s;

  renderBookmarks =
    prefix: attrs:
    let
      stripSpaces = s: builtins.replaceStrings [ " " "\t" "\n" ] [ "" "" "" ] s;
      startsWithAlnum = s: builtins.match "^[A-Za-z0-9].*" (stripSpaces s) != null;

      folderIconPrefix = "📁 ";
      urlIconPrefix = "";

      names = lib.attrNames attrs;
      folderNames = builtins.filter (n: builtins.isAttrs attrs.${n}) names;
      urlNames = builtins.filter (n: builtins.isString attrs.${n}) names;

      renderName =
        name:
        let
          value = attrs.${name};
          fullName = if prefix == "" then name else "${prefix}/${name}";
        in
        if builtins.isString value then
          let
            injectedUrlPrefix = if startsWithAlnum name then urlIconPrefix else "";
          in
          ''<DT><A HREF="${esc value}">+${esc "${injectedUrlPrefix}${fullName}"}</A>''
        else if builtins.isAttrs value then
          let
            injectedFolderPrefix = if startsWithAlnum name then folderIconPrefix else "";
          in
          ''
            <DT><H3>${esc "${injectedFolderPrefix}${name}"}</H3>
            <DL><p>
            ${renderBookmarks fullName value}
            </DL><p>
          ''
        else
          throw "firefox bookmark: value for '${name}' must be string or attrset!";
    in
    lib.concatStringsSep "\n" (map renderName (folderNames ++ urlNames));

  mkBookmarksHtml =
    config:
    let
      browserCfg = config.nx.common.browser.browser;
    in
    pkgs.writeText "firefox-bookmarks.html" ''
      <!DOCTYPE NETSCAPE-Bookmark-file-1>
      <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
      <TITLE>Bookmarks</TITLE>
      <H1>Bookmarks Menu</H1>
      <DL><p>
      <DT><H3 PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Toolbar</H3>
      <DL><p>
      ${renderBookmarks "" (browserCfg.final.bookmarks // firefoxSpecificBookmarks)}
      </DL><p>
      </DL><p>
    '';

  getDownloadDir =
    config: homeDir: defaultName:
    if self.isLinux && config.nx.linux.xdg."user-dirs".enable then
      "${homeDir}/${config.nx.linux.xdg."user-dirs".download}"
    else
      "${homeDir}/${defaultName}";

  niriLauncherEffectivelyEnabled =
    config:
    self.isLinux
    && config.nx.linux.desktop.niri.enable
    && config.nx.common.browser.firefox.enableNiriKeybinds
    && (self.user.settings.browser or null) == "firefox"
    && config.nx.preferences.desktop.programs.appLauncher != null;

  extensionType = lib.types.submodule {
    options = {
      addonId = lib.mkOption { type = lib.types.str; };
      fileId = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
      };
      filename = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      sha256 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      slug = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      settings = lib.mkOption {
        type = lib.types.nullOr lib.types.anything;
        default = null;
      };
      managedSettings = lib.mkOption {
        type = lib.types.nullOr lib.types.anything;
        default = null;
      };
      showInToolbar = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      forceLatest = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      disabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      allowedInPrivateWindows = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };

  baseExtensions =
    config: darkMode:
    {
      new-tab-override = {
        addonId = "newtaboverride@agenedia.com";
        slug = "new-tab-override";
        fileId = 4442226;
        filename = "new_tab_override-17.0.0";
        sha256 = "sha256-vedHJdHOSXodqKrUZSJIjAPWFXxUGpYpfiC5yEnAUxw=";
        settings = {
          type = "custom_url";
          url = config.nx.common.browser.browser.homeUrl;
          focus_website = false;
        };
      };
      ublock-origin = {
        addonId = "uBlock0@raymondhill.net";
        slug = "ublock-origin";
        showInToolbar = true;
      };
      privacy-badger = {
        addonId = "jid1-MnnxcxisBPnSXQ@jetpack";
        slug = "privacy-badger17";
      };
      adblock-for-youtube = {
        addonId = "jid1-q4sG8pYhq8KGHs@jetpack";
        slug = "adblock-for-youtube";
      };
      decentraleyes = {
        addonId = "jid1-BoFifL9Vbdl2zQ@jetpack";
        slug = "decentraleyes";
      };
      vimium = {
        addonId = "{d7742d87-e61d-4b78-b8a1-b469842139fa}";
        slug = "vimium-ff";
      };
      clearurls = {
        addonId = "{74145f27-f039-47ce-a470-a662b129930a}";
        slug = "clearurls";
        showInToolbar = true;
      };
    }
    // lib.optionalAttrs darkMode {
      dark-reader = {
        addonId = "addon@darkreader.org";
        slug = "darkreader";
      };
    }
    //
      lib.optionalAttrs (config.nx.linux.games.steam.enable || config.nx.linux.flatpacks.steam.enable)
        {
          steam-database = {
            addonId = "firefox-extension@steamdb.info";
            slug = "steam-database";
            allowedInPrivateWindows = false;
          };
        };

  mkExtensionUrl =
    ext:
    if !(ext.forceLatest or false) && (ext.sha256 or null) != null then
      "file://${
        pkgs.fetchurl {
          url = "https://addons.mozilla.org/firefox/downloads/file/${toString ext.fileId}/${ext.filename}.xpi";
          inherit (ext) sha256;
        }
      }"
    else
      "https://addons.mozilla.org/firefox/downloads/latest/${ext.slug}/latest.xpi";

  mkExtensionSettings =
    allExtensions:
    {
      "*" = {
        installation_mode = "blocked";
      };
    }
    // lib.mapAttrs' (
      _: ext:
      lib.nameValuePair ext.addonId {
        installation_mode = "force_installed";
        install_url = mkExtensionUrl ext;
        toolbar_pin = if (ext.showInToolbar or false) then "force_pinned" else "default_off";
        updates_disabled = !(ext.forceLatest or false) && (ext.sha256 or null) != null;
        private_browsing = ext.allowedInPrivateWindows or true;
      }
    ) allExtensions;

  mkPolicies =
    {
      config,
      syncEnable,
      darkMode,
      sidebar,
      lockedPreferences,
      extraPolicies,
      extensions,
      downloadDir,
      nextdnsID,
    }:
    let
      browserCfg = config.nx.common.browser.browser;
      defaultEngineName =
        if browserCfg.privacySearch then
          if browserCfg.startpageAsPrivacySearch then "Startpage" else capitalizeFirst "duckduckgo"
        else
          "Google";
      allExtensions = lib.filterAttrs (_: ext: !(ext.disabled or false)) (
        (baseExtensions config darkMode) // extensions
      );
      thirdPartyExtensions = lib.filterAttrs (
        _: ext: (ext.managedSettings or null) != null
      ) allExtensions;
      hasExternalPasswordManager =
        config.nx.common.passwords.bitwarden.enable || config.nx.common.passwords.keepassxc.enable;

      builtInSearchEnginesToRemove = [
        "Google"
        "Bing"
        "DuckDuckGo"
        "Wikipedia (en)"
        "eBay"
        "Perplexity"
      ];
    in
    {
      HttpsOnlyMode = "force_enabled";
      HttpAllowlist = [
        "http://localhost"
        "http://127.0.0.1"
        "http://[::1]"
      ];
      AppAutoUpdate = false;
      BackgroundAppUpdate = false;
      DisableAppUpdate = true;
      ExtensionUpdate = true;
      ManualAppUpdateOnly = true;
      DisableSystemAddonUpdate = true;
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      LocalNetworkAccess = {
        Enabled = true;
        BlockTrackers = true;
        EnablePrompting = false;
        Locked = true;
      };
      TranslateEnabled = false;
      GenerativeAI = {
        Chatbot = false;
        LinkPreviews = false;
        TabGroups = false;
        Locked = true;
      };
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
        EmailTracking = true;
        SuspectedFingerprinting = true;
        Category = "strict";
        BaselineExceptions = false;
        ConvenienceExceptions = false;
      };
      Permissions = {
        VirtualReality = {
          BlockNewRequests = true;
          Locked = true;
        };
      };
      Homepage = {
        URL = browserCfg.homeUrl;
        Locked = true;
        StartPage = "homepage";
      };
      SearchEngines = {
        Add = lib.mapAttrsToList (name: e: {
          Name = "@" + (capitalizeFirst name);
          Alias = "@${e.shortName}";
          URLTemplate = builtins.replaceStrings [ "{}" ] [ "{searchTerms}" ] e.queryUrl;
        }) browserCfg.final.searchEngines;
        Default = "@" + defaultEngineName;
        PreventInstalls = true;
        Locked = true;
        Remove = builtInSearchEnginesToRemove;
      };
      DisableSecurityBypass = {
        InvalidCertificate = true;
        SafeBrowsing = true;
      };

      DisableFormHistory = true;
      DisablePasswordReveal = true;
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;

      ExtensionSettings = mkExtensionSettings allExtensions;
      Preferences = {
        "browser.aboutConfig.showWarning" = lockFalse;
        "browser.tabs.closeWindowWithLastTab" = lockFalse;
        "browser.warnOnQuit" = lockFalse;
        "browser.tabs.warnOnClose" = lockFalse;
        "browser.tabs.warnOnCloseOtherTabs" = lockTrue;
        "media.autoplay.default" = lockValue 5;
        "dom.disable_open_during_load" = lockTrue;
        "pdfjs.disabled" = lockFalse;
        "network.dns.disablePrefetch" = lockTrue;
        "network.dns.disablePrefetchFromHTTPS" = lockTrue;
        "network.prefetch-next" = lockFalse;
        "network.predictor.enabled" = lockFalse;
        "network.http.speculative-parallel-limit" = lockValue 0;
        "network.captive-portal-service.enabled" = lockFalse;
        "network.connectivity-service.enabled" = lockFalse;
        "network.IDN_show_punycode" = lockTrue;
        "network.http.referer.XOriginPolicy" = lockValue 1;
        "network.http.referer.XOriginTrimmingPolicy" = lockValue 2;
        "media.peerconnection.ice.default_address_only" = lockTrue;
        "media.peerconnection.ice.no_host" = lockTrue;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = lockTrue;
        "browser.topsites.contile.enabled" = lockFalse;
        "browser.newtabpage.activity-stream.showSponsored" = lockFalse;
        "browser.newtabpage.activity-stream.system.showSponsored" = lockFalse;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = lockFalse;
        "browser.newtabpage.activity-stream.feeds.topsites" = lockFalse;
        "browser.newtabpage.activity-stream.showSearch" = lockFalse;
        "browser.tabs.firefox-view" = lockFalse;
        "browser.translations.enable" = lockFalse;
        "browser.translations.automaticallyPopup" = lockFalse;
        "browser.toolbars.bookmarks.visibility" = lockValue "never";
        "browser.bookmarks.file" = lockValue "${mkBookmarksHtml config}";
        "browser.download.dir" = lockValue downloadDir;
        "browser.download.folderList" = lockValue 2;
        "browser.download.useDownloadDir" = lockTrue;
        "dom.security.https_only_mode" = lockTrue;
        "dom.security.https_only_mode.upgrade_local" = lockFalse;
        "network.lna.enabled" = lockTrue;
        "network.lna.block_trackers" = lockTrue;
      }
      // lib.optionalAttrs (nextdnsID != null) {
        "network.trr.mode" = lockValue 3;
        "network.trr.uri" = lockValue "https://dns.nextdns.io/${nextdnsID}";
      }
      // lib.optionalAttrs self.isLinux {
        "widget.use-xdg-desktop-portal.mime-handler" = lockValue 1;
        "widget.use-xdg-desktop-portal.open-uri" = lockValue 1;
        "media.webspeech.synth.enabled" = lockFalse;
      }
      // lib.optionalAttrs self.isDarwin {
        "ui.key.accelKey" =
          let
            ctrlKey = 17;
          in
          lockValue ctrlKey;
      }
      // lib.optionalAttrs darkMode {
        "ui.systemUsesDarkTheme" = lockValue 1;
        "layout.css.prefers-color-scheme.content-override" = lockValue 0;
      }
      // lib.optionalAttrs hasExternalPasswordManager {
        "signon.rememberSignons" = lockFalse;
        "signon.autofillForms" = lockFalse;
        "signon.generation.enabled" = lockFalse;
        "signon.generation.available" = lockFalse;
        "signon.formlessCapture.enabled" = lockFalse;
        "signon.formRemovalCapture.enabled" = lockFalse;
        "signon.capture.inputChanges.enabled" = lockFalse;
        "signon.privateBrowsingCapture.enabled" = lockFalse;
        "signon.storeWhenAutocompleteOff" = lockFalse;
        "browser.contextual-password-manager.enabled" = lockFalse;
      }
      // lockedPreferences;
    }
    // lib.optionalAttrs hasExternalPasswordManager {
      PasswordManagerEnabled = false;
      OfferToSaveLogins = false;
    }
    // lib.optionalAttrs (!syncEnable) {
      DisableAccounts = true;
      DisableFirefoxAccounts = true;
    }
    // lib.optionalAttrs (thirdPartyExtensions != { }) {
      "3rdparty".Extensions = lib.mapAttrs' (
        _: ext: lib.nameValuePair ext.addonId ext.managedSettings
      ) thirdPartyExtensions;
    }
    // extraPolicies;
in
{
  name = "firefox";

  group = "browser";
  input = "common";

  submodules = {
    common.browser = [ "browser" ];
  };

  options = {
    profileName = lib.mkOption {
      type = lib.types.str;
      default = "default-release";
    };
    syncEnable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    darkMode = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    sidebar = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    lockedPreferences = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
    extraPolicies = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
    firejailXDGAllowedUserDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "download" ];
    };
    defaultDownloadsName = lib.mkOption {
      type = lib.types.str;
      default = "Downloads";
    };
    nextdnsID = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    extensions = lib.mkOption {
      type = lib.types.attrsOf extensionType;
      default = { };
    };
    enableNiriKeybinds = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    firejailExtraRules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  module = {

    home =
      {
        config,
        profileName,
        extensions,
        darkMode,
        sidebar,
        ...
      }:
      let
        allExtensions = lib.filterAttrs (_: ext: !(ext.disabled or false)) (
          (baseExtensions config darkMode) // extensions
        );
        settingsExtensions = lib.filterAttrs (_: ext: (ext.settings or null) != null) (
          lib.mapAttrs (
            name: ext:
            if name == "new-tab-override" && !niriLauncherEffectivelyEnabled config then
              ext
              // {
                settings = {
                  type = "custom_url";
                  url = "about:blank";
                  focus_website = false;
                };
              }
            else
              ext
          ) allExtensions
        );
        userChromeCSS =
          let
            hideSingleTabToolbarCSS = ''
              #TabsToolbar:has(.tabbrowser-tab:only-of-type) { display: none !important; }
              #tabbrowser-tabs .tabbrowser-tab:only-of-type,
              #tabbrowser-tabs .tabbrowser-tab:only-of-type + #tabbrowser-arrowscrollbox-periphery {
                display: none !important;
              }
              #tabbrowser-tabs, #tabbrowser-arrowscrollbox { min-height: 0 !important; }
            '';

            hideBookmarkToolbarIconsCSS = ''
              .bookmark-item .toolbarbutton-icon { display: none !important; }
              .bookmark-item .menu-icon { display: none !important; }
            '';

            forceBlackToolbarBackgroundsCSS = ''
              #navigator-toolbox,
              #nav-bar,
              #PersonalToolbar { background-color: #000000 !important; }
              .urlbar-background { background-color: #000000 !important; border-color: #000000 !important; }
              #urlbar-input { background-color: transparent !important; }
              .urlbarView,
              .urlbarView-body-inner { background-color: #000000 !important; }
              .urlbarView { border-color: #000000 !important; }
              #urlbar-searchmode-switcher { background-color: #000000 !important; }
              .searchmode-switcher-popup { background-color: #000000 !important; border-color: #000000 !important; box-shadow: none !important; }
              .searchmode-switcher-popup-description,
              .searchmode-switcher-installed,
              .searchmode-switcher-local,
              .searchmode-switcher-popup-search-settings-button { background-color: #000000 !important; }
              .tabs-alltabs-button { background-color: #000000 !important; }
              .sticky-container,
              .card-container { background-color: #000000 !important; }
              .panel-subview-body,
              .panel-header,
              .panel-no-padding,
              .cui-widget-panelview,
              #unified-extensions-area { background-color: #000000 !important; }
              #site-information-popup { background-color: #000000 !important; }
              #toolbar-context-menu { background-color: #000000 !important; }
            '';

            forceBlackMainCSS = ''
              #main-window,
              .notificationbox-stack,
              .infobar { background-color: #000000 !important; }
            '';

            forceBlackContextMenuCSS = ''
              .tooltip-xul-wrapper,
              .tooltip-container,
              #toolbox-meatball-menu-button-panel,
              .tooltip-filler,
              .tooltip-panel,
              .tooltip-arrow,
              #toolbox-meatball-menu,
              .checkbox-container,
              .menu-standard-padding,
              .menuitem,
              button.command,
              button.command.iconic,
              span.label,
              span.accelerator,
              #mainPopupSet,
              #contextAreaContextMenu,
              #context-back,
              #context-forward,
              #context-reload,
              #context-bookmarkpage,
              #context-sep-navigation,
              #context-navigation { background-color: #000000 !important; }

              .menupopup-arrowscrollbox {
                background-color: #000000 !important;
                border-color: #000000 !important;
                border-radius: 0 !important;
              }
            '';

            disableVPNButtonCSS = ''
              #ipprotection-button { display: none !important; }
            '';

            disableSidebarButtonCSS = ''
              #sidebar-button { display: none !important; }
            '';

            disableStarIconCSS = ''
              #star-button-box { display: none !important; }
            '';

            disableReaderModeButtonCSS = ''
              #reader-mode-button { display: none !important; }
            '';

            hideToolbarTabStopCSS = ''
              toolbartabstop { display: none !important; }
            '';

            removeTabsLeftBorderCSS = ''
              #tabbrowser-tabs { border-inline-start: none !important; }
            '';

            disableFirefoxViewButtonCSS = ''
              #firefox-view-button,
              #firefox-view-button + toolbarseparator { display: none !important; }
            '';

            adjustToolboxButtonHoverColorsCSS = ''
              #navigator-toolbox {
                --toolbarbutton-hover-background: #1a1a1a;
                --toolbarbutton-active-background: #2a2a2a;
                --toolbarbutton-border-radius: 0px;
              }
            '';

            squareOffPopupsAndButtonsCSS = ''
              .urlbarView-row,
              .urlbarView-row-inner,
              .urlbarView-action-btn,
              menuitem,
              menu,
              .panel-arrowcontent,
              .subviewbutton,
              .toolbarbutton-1 { border-radius: 0 !important; }
            '';

            hideTitlebarCloseButtonCSS = ''
              .titlebar-button.titlebar-close { display: none !important; }
            '';

            activeTabBackgroundCSS = ''
              .tabbrowser-tab[selected="true"] .tab-background { background-color: #1a1a1a !important; }
            '';

            squareTabBackgroundCSS = ''
              .tab-background { border-radius: 0 !important; }
            '';

            disableUnifiedExtensionsButtonCSS = ''
              #unified-extensions-button { display: none !important; }
            '';

            toolbarExtensionsForceHiddenCSS = ''
              #nav-bar .webextension-browser-action { display: none !important; }
            '';

            toolbarExtensionsForceShownCSS = lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                _: ext:
                "#nav-bar .webextension-browser-action[data-extensionid=\"${ext.addonId}\"] { display: revert !important; }"
              ) (lib.filterAttrs (_: ext: (ext.showInToolbar or false)) allExtensions)
            );
          in
          lib.concatStringsSep "\n" (
            [
              hideSingleTabToolbarCSS
              hideBookmarkToolbarIconsCSS
              forceBlackToolbarBackgroundsCSS
              forceBlackMainCSS
              forceBlackContextMenuCSS
              disableVPNButtonCSS
              disableSidebarButtonCSS
              disableStarIconCSS
              disableReaderModeButtonCSS
              hideToolbarTabStopCSS
              removeTabsLeftBorderCSS
              disableFirefoxViewButtonCSS
              adjustToolboxButtonHoverColorsCSS
              squareOffPopupsAndButtonsCSS
              hideTitlebarCloseButtonCSS
              activeTabBackgroundCSS
              squareTabBackgroundCSS
            ]
            ++ (lib.optionals (allExtensions == { }) [
              disableUnifiedExtensionsButtonCSS
            ])
            ++ [
              toolbarExtensionsForceHiddenCSS
              toolbarExtensionsForceShownCSS
            ]
          );
      in
      {
        assertions =
          lib.mapAttrsToList (name: ext: {
            assertion = (ext.slug or null) != null;
            message = "nx.common.browser.firefox: extension '${name}' must have slug set (required for forceLatest fallback)!";
          }) allExtensions
          ++ lib.mapAttrsToList (name: ext: {
            assertion =
              let
                hasSha = (ext.sha256 or null) != null;
                hasId = (ext.fileId or null) != null;
                hasFile = (ext.filename or null) != null;
              in
              (hasSha && hasId && hasFile) || (!hasSha && !hasId && !hasFile);
            message = "nx.common.browser.firefox: extension '${name}' requires sha256, fileId, and filename to all be set together or not at all!";
          }) allExtensions;

        programs.firefox.enable = true;

        stylix = lib.mkIf (self.isModuleEnabled "style.stylix") {
          targets.firefox.profileNames = [ profileName ];
        };

        programs.firefox.profiles.${profileName} = {
          extensions.force = true;
          extensions.settings = lib.mapAttrs' (
            _: ext: lib.nameValuePair ext.addonId { settings = ext.settings; }
          ) settingsExtensions;
          settings = {
            "browser.places.importBookmarksHTML" = true;
            "devtools.theme" = "dark";
            "devtools.toolbox.host" = "window";
            "privacy.donottrackheader.enabled" = true;
            "security.pki.crlite_mode" = 2;
          }
          // lib.optionalAttrs (!sidebar) {
            "sidebar.revamp" = false;
          };

          userContent = lib.mkIf (
            config.nx.common.browser.browser.final.userContentCSS != null
          ) config.nx.common.browser.browser.final.userContentCSS.data;
          userChrome = userChromeCSS;
        };
        home.file.".local/bin/firefox-get-extension-manifest" = {
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail
            if [ $# -ne 1 ]; then
              echo "Usage: firefox-get-extension-manifest <xpi-url>" >&2
              exit 1
            fi
            url="$1"
            if [[ "$url" != https://addons.mozilla.org/firefox/downloads/* ]]; then
              echo "Error: URL must start with https://addons.mozilla.org/firefox/downloads/" >&2
              exit 1
            fi
            tmp="''${url##*/file/}"
            file_id="''${tmp%%/*}"
            filename=$(basename "$url")
            filename="''${filename%.xpi}"
            prefetch_json=$(${
              helpers.packageFile args pkgs.nix "bin/nix"
            } store prefetch-file --json "$url" 2>/dev/null)
            store_path=$(printf '%s' "$prefetch_json" | ${
              helpers.packageFile args pkgs.jq "bin/jq"
            } -r .storePath)
            sha256=$(printf '%s' "$prefetch_json" | ${helpers.packageFile args pkgs.jq "bin/jq"} -r .hash)
            addon_id=$(${helpers.packageFile args pkgs.unzip "bin/unzip"} -p "$store_path" manifest.json | ${
              helpers.packageFile args pkgs.jq "bin/jq"
            } -r '.browser_specific_settings.gecko.id // .applications.gecko.id')
            encoded_id=$(printf '%s' "$addon_id" | ${helpers.packageFile args pkgs.jq "bin/jq"} -Rr @uri)
            slug=$(${
              helpers.packageFile args pkgs.curl "bin/curl"
            } -s "https://addons.mozilla.org/api/v5/addons/addon/''${encoded_id}/" | ${
              helpers.packageFile args pkgs.jq "bin/jq"
            } -r .slug)
            ok=1
            [[ "$file_id" =~ ^[0-9]+$ ]] || { echo "Error: could not parse fileId from URL" >&2; ok=0; }
            [ -n "$filename" ] || { echo "Error: could not parse filename from URL" >&2; ok=0; }
            [[ "$sha256" == sha256-* ]] || { echo "Error: unexpected sha256 format: $sha256" >&2; ok=0; }
            [ -n "$addon_id" ] && [ "$addon_id" != "null" ] || { echo "Error: addonId not found in manifest" >&2; ok=0; }
            [ -n "$slug" ] && [ "$slug" != "null" ] || { echo "Error: slug not found via AMO API" >&2; ok=0; }
            [ "$ok" -eq 1 ] || exit 1
            if [[ "$slug" =~ ^[a-zA-Z]([a-zA-Z-]*[a-zA-Z])?$ ]]; then
              printf '%s = {\n' "$slug"
            else
              printf '"%s" = {\n' "$slug"
            fi
            printf '  addonId = "%s";\n' "$addon_id"
            printf '  slug = "%s";\n' "$slug"
            printf '  fileId = %s;\n' "$file_id"
            printf '  filename = "%s";\n' "$filename"
            printf '  sha256 = "%s";\n' "$sha256"
            printf '};\n'
          '';
          executable = true;
        };

      };

    linux.home = config: {
      home.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

      home.persistence."${self.persist}" = {
        directories = [
          ".mozilla"
          ".config/mozilla"
          ".local/share/mozilla"
          ".cache/mozilla/firefox"
        ];
      };
    };

    linux.enabled =
      config:
      lib.mkMerge [
        (lib.mkIf (!(self.user.isStandalone or false)) {
          nx.linux.desktop-modules.desktop-files.entries.firefox = {
            exec = "${pkgs.systemd}/bin/systemd-run --user --collect --quiet /run/current-system/sw/bin/firefox --name firefox %U";
            name = "Firefox";
            icon = "firefox";
            validateIcon = false;
            categories = [
              "Network"
              "WebBrowser"
            ];
            mimeType = [
              "text/html"
              "text/xml"
              "application/xhtml+xml"
              "application/xml"
              "x-scheme-handler/http"
              "x-scheme-handler/https"
              "x-scheme-handler/ftp"
            ];
          };
        })
        {
          nx.linux.monitoring.journal-watcher.ignorePatterns = [
            {
              tag = "firefox";
              string = "Failed to enumerate devices of org\\.freedesktop\\.UPower.*";
              user = true;
              unitless = true;
            }
          ];
        }
      ];

    linux.integrated = config: {
      programs.firefox.package = lib.mkForce null;
      home.file.".local/bin/firefox-wrapper" = {
        text = ''
          #!/bin/sh
          exec /run/current-system/sw/bin/firefox "$@"
        '';
        executable = true;
      };
      home.packages = [
        (pkgs.writeShellScriptBin "firejail-firefox-ls" ''
          exec /run/wrappers/bin/firejail --profile=firefox -- ${pkgs.coreutils}/bin/ls -l "$@"
        '')
      ];
    };

    standalone =
      {
        config,
        syncEnable,
        darkMode,
        sidebar,
        lockedPreferences,
        extraPolicies,
        extensions,
        defaultDownloadsName,
        nextdnsID,
        ...
      }:
      let
        downloadDir = getDownloadDir config self.user.home defaultDownloadsName;
      in
      {
        programs.firefox = {
          policies = mkPolicies {
            inherit
              config
              syncEnable
              darkMode
              sidebar
              lockedPreferences
              extraPolicies
              extensions
              downloadDir
              nextdnsID
              ;
          };
        };
      };

    linux.standalone =
      {
        config,
        syncEnable,
        darkMode,
        sidebar,
        lockedPreferences,
        extraPolicies,
        extensions,
        defaultDownloadsName,
        ...
      }:
      {
        programs.firefox = {
          package = lib.mkDefault pkgs.firefox;
        };
        home.file.".local/bin/firefox-wrapper" = {
          text = ''
            #!/bin/sh
            exec ${pkgs.firefox}/bin/firefox "$@"
          '';
          executable = true;
        };
      };

    linux.system =
      {
        config,
        syncEnable,
        darkMode,
        sidebar,
        lockedPreferences,
        extraPolicies,
        extensions,
        firejailXDGAllowedUserDirs,
        firejailExtraRules,
        defaultDownloadsName,
        nextdnsID,
        ...
      }:
      let
        ud = config.nx.linux.xdg."user-dirs";
        home = self.user.home;
        validKeys = lib.filter (k: builtins.hasAttr k ud) firejailXDGAllowedUserDirs;
        resolvedDirs = map (k: {
          key = k;
          dir = ud.${k};
        }) validKeys;
        downloadDir = getDownloadDir config home defaultDownloadsName;
      in
      {
        programs.firefox = {
          enable = true;
          policies = mkPolicies {
            inherit
              config
              syncEnable
              darkMode
              sidebar
              lockedPreferences
              extraPolicies
              extensions
              downloadDir
              nextdnsID
              ;
          };
        };

        programs.firejail = {
          enable = true;
          wrappedBinaries.firefox = {
            executable = "${helpers.packageFile args pkgs.firefox "bin/firefox"}";
            profile = "${helpers.packageFile args pkgs.firejail "etc/firejail/firefox.profile"}";
            desktop = "${helpers.packageFile args pkgs.firefox "share/applications/firefox.desktop"}";
          };
        };

        assertions = [
          {
            assertion = lib.length validKeys == lib.length firejailXDGAllowedUserDirs;
            message = "nx.common.browser.firefox.firejailXDGAllowedUserDirs contains invalid user-dirs key(s)!";
          }
        ];

        environment.etc."firejail/firefox.local".text =
          let
            generalRules = [
              "dbus-user.talk org.freedesktop.portal.Desktop"
              "env GIO_USE_PORTALS=1"
              "noblacklist /dev/null"
              "whitelist /dev/null"
            ];
            screenshareRules = [
              "noblacklist /dev/dri"
              "whitelist /dev/dri"
            ];
            cameraRules = [
              "dbus-user.talk org.freedesktop.portal.Camera"
              "noblacklist /dev/video*"
              "whitelist /dev/video*"
            ];
            screensaverRules = [
              "dbus-user.talk org.freedesktop.ScreenSaver"
            ];
            notificationRules = [
              "dbus-user.talk org.freedesktop.Notifications"
            ];
          in
          lib.concatStringsSep "\n" (
            (map (e: "whitelist ${home}/${e.dir}") resolvedDirs)
            ++ lib.optionals (self.linux.isModuleEnabled "storage.luks-data-drive") (
              let
                mountPoint = (self.linux.getModuleConfig "storage.luks-data-drive").mountpoint;
              in
              map (e: "whitelist ${mountPoint}/${self.host.hostname}/${home}/${e.dir}") resolvedDirs
            )
            ++ generalRules
            ++ screenshareRules
            ++ cameraRules
            ++ screensaverRules
            ++ notificationRules
            ++ lib.optionals (helpers.resolveFromHostOrUser config [ "hardware" "gpu" ] null == "nvidia") [
              "private-etc egl"
              "noblacklist /dev/nvidia*"
              "whitelist /dev/nvidia*"
            ]
            ++ lib.optionals (config.nx.linux.security.yubikey.enable) [
              "noblacklist /dev/hidraw*"
              "whitelist /dev/hidraw*"
              "ignore noinput"
              "ignore nou2f"
            ]
            ++ lib.optionals (config.nx.linux.location.geoclue2.enable) [
              "ignore dbus-system none"
              "dbus-system filter"
              "dbus-system.talk org.freedesktop.GeoClue2"
            ]
            ++ firejailExtraRules
          );

        environment.systemPackages = [
          (pkgs.writeShellScriptBin "firefox-unsafe" ''
            exec ${helpers.packageFile args pkgs.firefox "bin/firefox"} "$@"
          '')
        ];
      };

    darwin.home =
      {
        config,
        syncEnable,
        darkMode,
        profileName,
        sidebar,
        lockedPreferences,
        extraPolicies,
        extensions,
        defaultDownloadsName,
        ...
      }:
      let
        userCSS = config.nx.common.browser.browser.final.userContentCSS;
      in
      {
        programs.firefox.package = lib.mkForce null;
        home.file.".local/bin/firefox-wrapper" = {
          text = ''
            #!/bin/sh
            exec open -a Firefox "$@"
          '';
          executable = true;
        };

        home.activation."firefox-userContent-copy" = lib.mkIf (userCSS != null) (
          (self.hmLib config).dag.entryAfter [ "linkGeneration" ] ''
            ${pkgs.writeShellScript "firefox-copy-userContent" ''
              base_dir="$HOME/Library/Application Support/Firefox/Profiles/${profileName}"
              if [[ -d "$base_dir" ]]; then
                css_dir="$base_dir/chrome"
                mkdir -p "$css_dir"
                rm -f "$css_dir/userContent.css"
                rm -f "$css_dir/userContent.css.${self.variables.home-manager-backup-extension}"
                cp "${userCSS.derivation}" "$css_dir/userContent.css"
               fi
            ''} || true
          ''
        );
      };

    darwin.enabled = config: {
      nx.homebrew.casks = [ "firefox" ];
    };

    ifEnabled.linux.desktop.niri.home =
      { config, enableNiriKeybinds, ... }:
      let
        isSelectedBrowser = (self.user.settings.browser or null) == "firefox";
        appLauncher = config.nx.preferences.desktop.programs.appLauncher;
        browserCfg = config.nx.common.browser.browser;
        defaultSearch = browserCfg.defaultSearchUrl;

        flattenBookmarks =
          prefix: bookmarks:
          lib.concatMapAttrs (
            name: value:
            let
              fullName = if prefix == "" then name else "${prefix}/${name}";
            in
            if builtins.isString value then
              { "${fullName}" = value; }
            else if builtins.isAttrs value && builtins.length (builtins.attrNames value) > 0 then
              flattenBookmarks fullName value
            else
              { }
          ) bookmarks;

        flattenedBookmarks = flattenBookmarks "" (browserCfg.final.bookmarks // firefoxSpecificBookmarks);
      in
      {
        home.file.".local/bin/firefox-bookmark" = lib.mkIf (niriLauncherEffectivelyEnabled config) (
          let
            namesArgs = lib.escapeShellArgs (map (n: "+${n}") (lib.attrNames flattenedBookmarks));
            caseStatements = lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                name: url: "    ${lib.escapeShellArg "+${name}"}) firefox ${lib.escapeShellArg url} ;;"
              ) flattenedBookmarks
            );
            launcherCmd = lib.escapeShellArgs (
              helpers.runWithAbsolutePath config appLauncher appLauncher.dmenuCommand {
                prompt = "Bookmark: ";
                placeholder = "Select a bookmark";
                width = 80;
                lines = 15;
              }
            );
          in
          {
            text = ''
              #!/usr/bin/env bash
              selection=$(printf '%s\n' ${namesArgs} | ${launcherCmd}) || exit 0
              [ -z "$selection" ] && exit 0
              case "$selection" in
              ${caseStatements}
              esac
            '';
            executable = true;
          }
        );

        programs.niri = {
          settings = {
            binds =
              with config.lib.niri.actions;
              lib.optionalAttrs (enableNiriKeybinds && isSelectedBrowser) {
                "Mod+Ctrl+Alt+N" = {
                  action = spawn-sh "firefox";
                  hotkey-overlay.title = "Apps:Browser";
                };
              }
              // lib.optionalAttrs (niriLauncherEffectivelyEnabled config) (
                let
                  searchLauncherCmd = lib.escapeShellArgs (
                    helpers.runWithAbsolutePath config appLauncher appLauncher.dmenuCommand {
                      prompt = "Web Search: ";
                      placeholder = "Enter search query";
                      width = 60;
                      lines = 0;
                    }
                  );
                  engines = browserCfg.final.searchEngines;
                  defaultEngineKey =
                    if browserCfg.privacySearch then
                      if browserCfg.startpageAsPrivacySearch then "startpage" else "duckduckgo"
                    else
                      "google";
                  nonDefaultKeys = lib.sort (a: b: a < b) (
                    lib.filter (k: k != defaultEngineKey) (lib.attrNames engines)
                  );
                  orderedKeys =
                    (lib.optional (builtins.hasAttr defaultEngineKey engines) defaultEngineKey) ++ nonDefaultKeys;
                  displayName = key: "@${capitalizeFirst key}";
                  engineNamesArgs = lib.escapeShellArgs (map displayName orderedKeys);
                  engineCases = lib.concatStringsSep "\n" (
                    map (
                      key:
                      let
                        parts = lib.splitString "{}" engines.${key}.queryUrl;
                        before = builtins.elemAt parts 0;
                        after = if builtins.length parts > 1 then builtins.elemAt parts 1 else "";
                      in
                      "  ${lib.escapeShellArg (displayName key)}) url_before=${lib.escapeShellArg before} url_after=${lib.escapeShellArg after} ;;"
                    ) orderedKeys
                  );
                  engineLauncherCmd = lib.escapeShellArgs (
                    helpers.runWithAbsolutePath config appLauncher appLauncher.dmenuCommand {
                      prompt = "Engine: ";
                      placeholder = "Select search engine";
                      width = 40;
                      lines = builtins.length orderedKeys;
                    }
                  );
                in
                {
                  "Mod+Alt+Space" = {
                    action = spawn-sh ''
                      engine=$(printf '%s\n' ${engineNamesArgs} | ${engineLauncherCmd})
                      [ -z "$engine" ] && exit 0
                      case "$engine" in
                      ${engineCases}
                        *) exit 1 ;;
                      esac
                      query=$(echo "" | ${searchLauncherCmd})
                      [ -z "$query" ] && exit 0
                      encoded=$(printf '%s' "$query" | ${helpers.packageFile args pkgs.jq "bin/jq"} -Rr @uri)
                      firefox "$url_before$encoded$url_after"
                    '';
                    hotkey-overlay.title = "Apps:Web Search";
                  };
                  "Mod+Ctrl+Space" = {
                    action = spawn-sh "firefox-bookmark";
                    hotkey-overlay.title = "Apps:Bookmarks";
                  };
                }
              );

            window-rules = [
              {
                matches = [ { app-id = "firefox"; } ];
                open-on-workspace = "2";
                open-focused = false;
              }
            ];
          };
        };
      };
  };
}
