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
      qutebrowser = "https://www.qutebrowser.org/doc/help/settings.html";
      nix-datatypes = "https://nlewo.github.io/nixos-manual-sphinx/development/option-types.xml.html";
      nixos-wiki = "https://nixos.wiki/wiki/Main_Page";
      mynixos = "https://mynixos.com/";
    };
    baseSearchEngines = {
      pkgs = "https://search.nixos.org/packages?query={}";
      opts = "https://search.nixos.org/options?query={}";
      nix = "https://mynixos.com/search?q={}";
    };
    darkMode = true;
    autoplay = false;
    blockAds = false;
    spoofUserAgent = false;
    fontSize = 12;
    webFontSize = 17;
    additionalStartPages = [ ];
    additionalSearchEngines = { };
    addHomeToStartPages = true;
    additionalAliases = { };
    locale = "en-GB";
    dictLanguages = [
      "de-DE"
      "en-GB"
    ];
    whitelistPatterns = [ ];
    editor = [
      "ghostty"
      "-e"
      "nvim"
    ];
    fileManager = [ "dolphin" ];
    bookmarkGroups = { };
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      defaultSearch =
        if self.settings.privacySearch then
          "https://duckduckgo.com/?q="
        else
          "https://${self.settings.googleDomain}/search?q=";

      homeUrl =
        if self.settings.home != null then
          self.settings.home
        else if self.settings.privacySearch then
          "https://duckduckgo.com"
        else
          "https://${self.settings.googleDomain}";

      userAgent = "Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}";
    in
    {
      programs.qutebrowser = {
        enable = true;
        package = lib.mkDefault pkgs-unstable.qutebrowser;

        loadAutoconfig = false;

        settings = {
          confirm_quit = [ "downloads" ];
          new_instance_open_target = "window";
          fonts = {
            default_size = lib.mkForce ((builtins.toString self.settings.fontSize) + "pt");
            web = {
              size = {
                default = lib.mkForce self.settings.webFontSize;
                default_fixed = lib.mkForce (builtins.floor (self.settings.webFontSize * 0.9));
                minimum = 0;
                minimum_logical = lib.mkForce (builtins.floor (self.settings.webFontSize * 0.6));
              };
            };
          };
          url = {
            open_base_url = true;
            default_page = homeUrl;
            start_pages =
              (
                if (self.settings.addHomeToStartPages || self.settings.additionalStartPages == [ ]) then
                  [ homeUrl ]
                else
                  [ ]
              )
              ++ self.settings.additionalStartPages;
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
                fg = lib.mkForce "#dddddd";
                bg = lib.mkForce "#444444";
              };
            };
            hints = {
              bg = lib.mkForce "#000000";
              fg = lib.mkForce "#99ee88";
              match = {
                fg = lib.mkForce "#ee9988";
              };
            };
            webpage = {
              darkmode = {
                enabled = self.settings.darkMode;
              };
              preferred_color_scheme = if self.settings.darkMode then "dark" else "auto";
            };
          };
          content = {
            canvas_reading = true;
            cache = {
              maximum_pages = 5;
            };
            fullscreen = {
              window = self.isLinux && isNiriEnabled;
            };

            default_encoding = "utf-8";
            pdfjs = true;
            autoplay = self.settings.autoplay;
            blocking = lib.mkIf (self.settings.blockAds && (self.isDarwin || self.isLinux)) {
              enabled = true;
              method = if self.isLinux then "both" else "hosts";
              whitelist = self.settings.whitelistPatterns;
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
              accept = "all";
            };
            headers = {
              accept_language = "${self.settings.locale},${builtins.head (lib.strings.splitString "-" self.settings.locale)};q=0.9";
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
            position = "bottom";
            location = {
              directory = config.xdg.userDirs.download;
              prompt = false;
              remember = false;
            };
          };
          hints = {
            uppercase = true;
          };
          tabs = {
            show = "multiple";
            last_close = "default-page";
          };
          messages = {
            timeout = 1500;
          };
          scrolling = {
            smooth = true;
            bar = "always";
          };
          completion = {
            use_best_match = true;
            quick = true;
            show = "always";
            delay = 0;
            min_chars = 1;
          };
          auto_save = {
            session = true;
          };
          spellcheck = {
            languages = self.settings.dictLanguages;
          };
          editor = {
            command = self.settings.editor ++ [
              "{file}"
            ];
          };
          fileselect = {
            folder.command = self.settings.fileManager ++ [
              "{}"
            ];
            multiple_files.command = self.settings.fileManager ++ [
              "{}"
            ];
            single_file.command = self.settings.fileManager ++ [
              "{}"
            ];
          };
        }
        // self.settings.customSettings;

        searchEngines =
          let
            amazonSearch = lib.optionalAttrs self.settings.addAmazonSearch {
              a = "https://${self.settings.amazonDomain}/s?k={}";
            };
          in
          {
            DEFAULT = defaultSearch + "{}";
            default = defaultSearch + "{}";
            d = "https://duckduckgo.com/?q={}";
            g = "https://${self.settings.googleDomain}/search?q={}";
          }
          // self.settings.baseSearchEngines
          // amazonSearch
          // self.settings.additionalSearchEngines;

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

        aliases =
          let
            getMatchingBookmarks =
              pattern: lib.filterAttrs (name: url: lib.hasPrefix pattern name) self.settings.customBookmarks;

            generateOpenCommand =
              mode: urls:
              let
                urlList = lib.attrValues urls;
              in
              if mode == "window" then
                if self.isDarwin then
                  "spawn --detach open -n -a qutebrowser --args ${builtins.concatStringsSep " " urlList}"
                else
                  "spawn --detach qutebrowser ${builtins.concatStringsSep " " urlList}"
              else
                let
                  openFlag =
                    if mode == "background" then
                      "-b"
                    else if mode == "tab" then
                      "-t"
                    else
                      throw "Invalid bookmark mode, only ['tab', 'background', 'window']";
                  commands = map (url: "open ${openFlag} ${url}") urlList;
                in
                builtins.concatStringsSep " ;; " commands;

            bookmarkGroupAliases = lib.mapAttrs' (
              groupName: mode:
              let
                matchingBookmarks = getMatchingBookmarks groupName;
                command = generateOpenCommand mode matchingBookmarks;
                aliasName = "group-${builtins.replaceStrings [ "/" ] [ "-" ] groupName}";
              in
              lib.nameValuePair aliasName command
            ) self.settings.bookmarkGroups;
          in
          bookmarkGroupAliases // self.settings.additionalAliases;

        keyMappings = {
          "~" = "<Shift-Escape>";
        };

        keyBindings = {
          normal = {
            "gt" = lib.mkForce "tab-next";
            "gT" = lib.mkForce "tab-prev";
            "gs" = lib.mkForce "cmd-set-text -s :tab-select";
            "<Ctrl-Tab>" = lib.mkForce "tab-next";
            "<Ctrl-Shift-Tab>" = lib.mkForce "tab-prev";
            "<Alt-Tab>" = lib.mkForce "tab-focus last";
            "gv" = lib.mkForce ":bind";
            "<Ctrl-n>" = lib.mkForce "open -w";
            "<Ctrl-Left>" = lib.mkForce "back";
            "<Ctrl-Right>" = lib.mkForce "forward";
          };
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

      home.file.".local/bin/qutebrowser-install-dicts" = {
        text = ''
          #!/usr/bin/env bash
          set -e

          DICTCLI="$(find /nix/store/*-qutebrowser-*/ -iname '*dictcli.py*' | head -1)"

          if [ -z "$DICTCLI" ]; then
            echo "Error: Could not find dictcli.py in qutebrowser package"
            exit 1
          fi

          echo "Found dictcli.py at: $DICTCLI"

          ${lib.concatMapStringsSep "\n" (lang: ''
            echo "Installing dictionary: ${lang}"
            "$DICTCLI" install "${lang}"
          '') self.settings.dictLanguages}

          echo "All dictionaries installed successfully!"
        '';
        executable = true;
      };

      home.file.".local/bin/qutebrowser-bookmarks-from-firefox" = {
        source = self.file "qutebrowser-bookmarks-from-firefox";
        executable = true;
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+N" = {
              action = spawn-sh "qutebrowser";
              hotkey-overlay.title = "Apps:Browser";
            };
            "Mod+Alt+Space" = {
              action = spawn-sh ''
                query=$(echo "" | fuzzel --dmenu --prompt="Web Search: " --placeholder="Enter search query"  --width=60 --lines=0)
                if [ -n "$query" ]; then
                  qutebrowser "${defaultSearch}$query"
                fi
              '';
              hotkey-overlay.title = "Apps:Web Search";
            };
          };
        };
      };
    };
}
