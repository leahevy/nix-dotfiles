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
  name = "qutebrowser-config";

  defaults = {
    privacySearch = true;
    addAmazonSearch = false;
    amazonDomain = "amazon.com";
    googleDomain = "google.com";
    home = null;
    customBookmarks = { };
    customSettings = { };
    baseBookmarks = {
      nixpkgs = "https://github.com/NixOS/nixpkgs";
      qb = "https://www.qutebrowser.org/doc/help/settings.html";
    };
    darkMode = true;
    autoplay = false;
    blockAds = true;
    spoofUserAgent = false;
    fontSize = 12;
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      homeUrl =
        if self.settings.home != null then
          self.settings.home
        else if self.settings.privacySearch then
          "https://duckduckgo.com"
        else
          "https://${self.settings.googleDomain}";

      userAgent =
        if self.isDarwin then
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
        else
          "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36";
    in
    {
      programs.qutebrowser = {
        enable = true;
        package = lib.mkDefault (self.dummyPackage "qutebrowser");

        loadAutoconfig = false;

        settings = {
          fonts = {
            default_size = lib.mkForce ((builtins.toString self.settings.fontSize) + "pt");
          };
          url = {
            start_pages = [ homeUrl ];
          };
          window = {
            hide_decoration = isNiriEnabled;
            transparent = true;
          };
          colors = {
            contextmenu = {
              menu = {
                fg = lib.mkForce "#99ee88";
                bg = lib.mkForce "#000000";
              };
              selected = {
                fg = lib.mkForce "#000000";
                bg = lib.mkForce "#ddddff";
              };
              disabled = {
                fg = lib.mkForce "#444444";
                bg = lib.mkForce "#dddddd";
              };
            };
            webpage = {
              darkmode = {
                enabled = self.settings.darkMode;
              };
            };
          };
          content = {
            autoplay = self.settings.autoplay;
            blocking = lib.mkIf (self.settings.blockAds && (self.isDarwin || self.isLinux)) {
              enabled = true;
              method = if self.isLinux then "adblock" else "hosts";
            };
            javascript = {
              can_open_tabs_automatically = false;
            };
            geolocation = "ask";
            notifications = {
              enabled = "ask";
            };
            media = {
              audio_capture = "ask";
              video_capture = "ask";
            };
            cookies = {
              accept = "no-3rdparty";
            };
            headers = {
              do_not_track = true;
              referer = "same-domain";
              user_agent = lib.mkIf self.settings.spoofUserAgent userAgent;
            };
            tls = {
              certificate_errors = "ask";
            };
            webgl = true;
            dns_prefetch = false;
          };
          downloads = {
            location = {
              directory = config.xdg.userDirs.download;
              prompt = false;
              remember = false;
            };
          };
        }
        // self.settings.customSettings;

        searchEngines =
          let
            defaultSearch =
              if self.settings.privacySearch then
                "https://duckduckgo.com/?q={}"
              else
                "https://${self.settings.googleDomain}/search?q={}";

            amazonSearch = lib.optionalAttrs self.settings.addAmazonSearch {
              a = "https://${self.settings.amazonDomain}/s?k={}";
            };
          in
          {
            DEFAULT = defaultSearch;
            d = "https://duckduckgo.com/?q={}";
            g = "https://${self.settings.googleDomain}/search?q={}";
            nx = "https://search.nixos.org/packages?query={}";
            nxo = "https://search.nixos.org/options?query={}";
            mn = "https://mynixos.com/search?q={}";
          }
          // amazonSearch;

        quickmarks =
          let
            defaultQuickmarks = {
              home = homeUrl;
              google = "https://${self.settings.googleDomain}";
              duck = "https://duckduckgo.com";
            };

            amazonQuickmark = lib.optionalAttrs self.settings.addAmazonSearch {
              amazon = "https://${self.settings.amazonDomain}";
            };
          in
          defaultQuickmarks
          // amazonQuickmark
          // self.settings.baseBookmarks
          // self.settings.customBookmarks;

        keyMappings = {
          "~" = "<Shift-Escape>";
        };

        extraConfig = ''
          import os
          import glob

          init_dir = os.path.expanduser("~/.config/qutebrowser-init")
          if os.path.exists(init_dir):
              for config_file in sorted(glob.glob(os.path.join(init_dir, "*.py"))):
                  config.source(config_file)
        '';
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/qutebrowser"
          ".local/share/qutebrowser"
          ".cache/qutebrowser"
        ];
      };

      home.sessionVariables = {
        BROWSER = "qutebrowser";
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+N" = {
              action = spawn-sh "qutebrowser";
              hotkey-overlay.title = "Apps:Browser";
            };
          };
        };
      };
    };
}
