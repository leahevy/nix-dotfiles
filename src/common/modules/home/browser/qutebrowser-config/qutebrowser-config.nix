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
    startpageAsPrivacySearch = true;
    addAmazon = false;
    amazonDomain = "amazon.com";
    googleDomain = "google.com";
    home = null;
    bookmarks = { };
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
    askOnQuit = true;
    additionalStartPages = [ ];
    additionalSearchEngines = { };
    addHomeToStartPages = true;
    alwaysCreateKeepassxcKeybindings = false;
    additionalKeyMappings = { };
    additionalKeyBindings = { };
    keyBindings = {
      normal = {
        "<Escape>" = "clear-keychain ;; search ;; fullscreen --leave";
        "o" = "cmd-set-text -s :open";
        "<Space>" = "cmd-set-text -s :open /search";
        "z" = "cmd-set-text :open /";
        "<Alt+Space>" = "cmd-set-text :fg-group#";
        "<Ctrl+Space>" = "cmd-set-text :bg-group#";
        "go" = "cmd-set-text :open {url:pretty}";
        "O" = "cmd-set-text -s :open -t";
        "gO" = "cmd-set-text :open -t -r {url:pretty}";
        "xo" = "cmd-set-text -s :open -b";
        "xO" = "cmd-set-text :open -b -r {url:pretty}";
        "wo" = "cmd-set-text -s :open -w";
        "wO" = "cmd-set-text :open -w {url:pretty}";
        "/" = "cmd-set-text /";
        "<Shift+/>" = "cmd-set-text /";
        "?" = "cmd-set-text ?";
        ";" = "cmd-set-text :";
        "ga" = "open -t";
        "<Ctrl+t>" = "open -t";
        "<Ctrl+n>" = "open -w";
        "<Ctrl+Shift+n>" = "open -p";
        "d" = "tab-close";
        "<Ctrl+q>" = "tab-close";
        "<Ctrl+w>" = "tab-close";
        "<Ctrl+Shift+q>" = "close";
        "<Ctrl+Shift+w>" = "close";
        "D" = "tab-close -o";
        "co" = "tab-only";
        "T" = "cmd-set-text -sr :tab-focus";
        "gm" = "tab-move";
        "gK" = "tab-move -";
        "gJ" = "tab-move +";
        "J" = "tab-next";
        "<Ctrl+PgDown>" = "tab-next";
        "K" = "tab-prev";
        "<Ctrl+PgUp>" = "tab-prev";
        "gC" = "tab-clone";
        "r" = "reload";
        "R" = "reload -f";
        "H" = "back";
        "<Back>" = "back";
        "th" = "back -t";
        "wh" = "back -w";
        "L" = "forward";
        "<Forward>" = "forward";
        "tl" = "forward -t";
        "wl" = "forward -w";
        "<F11>" = "fullscreen";
        "f" = "hint";
        "F" = "hint all tab";
        "wf" = "hint all window";
        ":b" = "hint all tab-bg";
        ":f" = "hint all tab-fg";
        ":h" = "hint all hover";
        ":i" = "hint images";
        ":I" = "hint images tab";
        ":o" = "hint links fill :open {hint-url}";
        ":O" = "hint links fill :open -t -r {hint-url}";
        ":y" = "hint links yank";
        ":Y" = "hint links yank-primary";
        ":r" = "hint --rapid links tab-bg";
        ":R" = "hint --rapid links window";
        ":d" = "hint links download";
        ":t" = "hint inputs";
        "gi" = "hint inputs --first";
        "h" = "scroll left";
        "j" = "scroll down";
        "k" = "scroll up";
        "l" = "scroll right";
        "u" = "undo";
        "U" = "undo -w";
        "<Ctrl+Shift+t>" = "undo";
        "gg" = "scroll-to-perc 0";
        "G" = "scroll-to-perc";
        "n" = "search-next";
        "N" = "search-prev";
        "i" = "mode-enter insert";
        "v" = "mode-enter caret";
        "V" = "mode-enter caret ;; selection-toggle --line";
        "`" = "mode-enter set_mark";
        "'" = "mode-enter jump_mark";
        "yy" = "yank";
        "yY" = "yank -s";
        "yt" = "yank title";
        "yT" = "yank title -s";
        "yd" = "yank domain";
        "yD" = "yank domain -s";
        "yp" = "yank pretty-url";
        "yP" = "yank pretty-url -s";
        "ym" = "yank inline [{title}]({url:yank})";
        "yM" = "yank inline [{title}]({url:yank}) -s";
        "pp" = "open -- {clipboard}";
        "pP" = "open -- {primary}";
        "Pp" = "open -t -- {clipboard}";
        "PP" = "open -t -- {primary}";
        "wp" = "open -w -- {clipboard}";
        "wP" = "open -w -- {primary}";
        "b" = "cmd-set-text -s :quickmark-load";
        "B" = "cmd-set-text -s :quickmark-load -t";
        "wb" = "cmd-set-text -s :quickmark-load -w";
        "sf" = "save";
        "ss" = "cmd-set-text -s :set";
        "sl" = "cmd-set-text -s :set -t";
        "sk" = "cmd-set-text -s :bind";
        "-" = "zoom-out";
        "+" = "zoom-in";
        "=" = "zoom";
        "[[" = "navigate prev";
        "]]" = "navigate next";
        "{{" = "navigate prev -t";
        "}}" = "navigate next -t";
        "gu" = "navigate up";
        "gU" = "navigate up -t";
        "<Ctrl+a>" = "navigate increment";
        "<Ctrl+x>" = "navigate decrement";
        "wi" = "devtools";
        "wIh" = "devtools left";
        "wIj" = "devtools bottom";
        "wIk" = "devtools top";
        "wIl" = "devtools right";
        "wIw" = "devtools window";
        "wIf" = "devtools-focus";
        "gd" = "download";
        "ad" = "download-cancel";
        "cd" = "download-clear";
        "gf" = "view-source";
        "gt" = "tab-next";
        "<Ctrl+Tab>" = "tab-next";
        "<Ctrl+Shift+Tab>" = "tab-prev";
        "<Ctrl+^>" = "tab-focus last";
        "<Ctrl+v>" = "mode-enter passthrough";
        "<Ctrl+f>" = "scroll-page 0 1";
        "<Ctrl+b>" = "scroll-page 0 -1";
        "<Ctrl+d>" = "scroll-page 0 0.5";
        "<Ctrl+u>" = "scroll-page 0 -0.5";
        "g0" = "tab-focus 1";
        "g^" = "tab-focus 1";
        "<Alt+1>" = "tab-focus 1";
        "<Alt+2>" = "tab-focus 2";
        "<Alt+3>" = "tab-focus 3";
        "<Alt+4>" = "tab-focus 4";
        "<Alt+5>" = "tab-focus 5";
        "<Alt+6>" = "tab-focus 6";
        "<Alt+7>" = "tab-focus 7";
        "<Alt+8>" = "tab-focus 8";
        "<Alt+9>" = "tab-focus -1";
        "<Ctrl+1>" = "tab-focus 1";
        "<Ctrl+2>" = "tab-focus 2";
        "<Ctrl+3>" = "tab-focus 3";
        "<Ctrl+4>" = "tab-focus 4";
        "<Ctrl+5>" = "tab-focus 5";
        "<Ctrl+6>" = "tab-focus 6";
        "<Ctrl+7>" = "tab-focus 7";
        "<Ctrl+8>" = "tab-focus 8";
        "<Ctrl+9>" = "tab-focus -1";
        "g$" = "tab-focus -1";
        "<Ctrl+h>" = "home";
        "<Ctrl+s>" = "stop";
        "<Ctrl+Alt+p>" = "print";
        "Ss" = "set";
        "Sh" = "history";
        "<Return>" = "selection-follow";
        "<Ctrl+Return>" = "selection-follow -t";
        "." = "cmd-repeat-last";
        "<Ctrl+p>" = "tab-pin";
        "<Alt+m>" = "tab-mute";
        "gD" = "tab-give";
        "tsh" = "config-cycle -p -t -u *://{url:host}/* content.javascript.enabled ;; reload";
        "tSh" = "config-cycle -p -u *://{url:host}/* content.javascript.enabled ;; reload";
        "tsH" = "config-cycle -p -t -u *://*.{url:host}/* content.javascript.enabled ;; reload";
        "tSH" = "config-cycle -p -u *://*.{url:host}/* content.javascript.enabled ;; reload";
        "tsu" = "config-cycle -p -t -u {url} content.javascript.enabled ;; reload";
        "tSu" = "config-cycle -p -u {url} content.javascript.enabled ;; reload";
        "tph" = "config-cycle -p -t -u *://{url:host}/* content.plugins ;; reload";
        "tPh" = "config-cycle -p -u *://{url:host}/* content.plugins ;; reload";
        "tpH" = "config-cycle -p -t -u *://*.{url:host}/* content.plugins ;; reload";
        "tPH" = "config-cycle -p -u *://*.{url:host}/* content.plugins ;; reload";
        "tpu" = "config-cycle -p -t -u {url} content.plugins ;; reload";
        "tPu" = "config-cycle -p -u {url} content.plugins ;; reload";
        "tih" = "config-cycle -p -t -u *://{url:host}/* content.images ;; reload";
        "tIh" = "config-cycle -p -u *://{url:host}/* content.images ;; reload";
        "tiH" = "config-cycle -p -t -u *://*.{url:host}/* content.images ;; reload";
        "tIH" = "config-cycle -p -u *://*.{url:host}/* content.images ;; reload";
        "tiu" = "config-cycle -p -t -u {url} content.images ;; reload";
        "tIu" = "config-cycle -p -u {url} content.images ;; reload";
        "tch" =
          "config-cycle -p -t -u *://{url:host}/* content.cookies.accept all no-3rdparty never ;; reload";
        "tCh" =
          "config-cycle -p -u *://{url:host}/* content.cookies.accept all no-3rdparty never ;; reload";
        "tcH" =
          "config-cycle -p -t -u *://*.{url:host}/* content.cookies.accept all no-3rdparty never ;; reload";
        "tCH" =
          "config-cycle -p -u *://*.{url:host}/* content.cookies.accept all no-3rdparty never ;; reload";
        "tcu" = "config-cycle -p -t -u {url} content.cookies.accept all no-3rdparty never ;; reload";
        "tCu" = "config-cycle -p -u {url} content.cookies.accept all no-3rdparty never ;; reload";
        "<Alt+Tab>" = "tab-next";
        "<Alt+Shift+Tab>" = "tab-prev";
        "<Ctrl+Left>" = "back";
        "<Ctrl+Right>" = "forward";
        "gT" = "tab-prev";
        "gs" = "cmd-set-text -s :tab-select";
        "gv" = ":bind";
      };
      caret = {
        "v" = "selection-toggle";
        "V" = "selection-toggle --line";
        "<Space>" = "selection-toggle";
        "<Ctrl+Space>" = "selection-drop";
        "c" = "mode-enter normal";
        "j" = "move-to-next-line";
        "k" = "move-to-prev-line";
        "l" = "move-to-next-char";
        "h" = "move-to-prev-char";
        "e" = "move-to-end-of-word";
        "w" = "move-to-next-word";
        "b" = "move-to-prev-word";
        "o" = "selection-reverse";
        "]" = "move-to-start-of-next-block";
        "[" = "move-to-start-of-prev-block";
        "}" = "move-to-end-of-next-block";
        "{" = "move-to-end-of-prev-block";
        "0" = "move-to-start-of-line";
        "$" = "move-to-end-of-line";
        "gg" = "move-to-start-of-document";
        "G" = "move-to-end-of-document";
        "Y" = "yank selection -s";
        "y" = "yank selection";
        "<Return>" = "yank selection";
        "H" = "scroll left";
        "J" = "scroll down";
        "K" = "scroll up";
        "L" = "scroll right";
        "<Escape>" = "mode-leave";
      };
      command = {
        "<Ctrl+p>" = "command-history-prev";
        "<Ctrl+n>" = "command-history-next";
        "<Up>" = "completion-item-focus --history prev";
        "<Down>" = "completion-item-focus --history next";
        "<Shift+Tab>" = "completion-item-focus prev";
        "<Tab>" = "completion-item-focus next";
        "<Ctrl+Tab>" = "completion-item-focus next-category";
        "<Ctrl+Shift+Tab>" = "completion-item-focus prev-category";
        "<PgDown>" = "completion-item-focus next-page";
        "<PgUp>" = "completion-item-focus prev-page";
        "<Ctrl+d>" = "completion-item-del";
        "<Shift+Del>" = "completion-item-del";
        "<Ctrl+c>" = "completion-item-yank";
        "<Ctrl+Shift+c>" = "completion-item-yank --sel";
        "<Return>" = "command-accept";
        "<Ctrl+Return>" = "command-accept --rapid";
        "<Ctrl+b>" = "rl-backward-char";
        "<Ctrl+f>" = "rl-forward-char";
        "<Alt+b>" = "rl-backward-word";
        "<Alt+f>" = "rl-forward-word";
        "<Ctrl+a>" = "rl-beginning-of-line";
        "<Ctrl+e>" = "rl-end-of-line";
        "<Ctrl+u>" = "rl-unix-line-discard";
        "<Ctrl+k>" = "rl-kill-line";
        "<Alt+d>" = "rl-kill-word";
        "<Ctrl+w>" = "rl-rubout \" \"";
        "<Ctrl+Shift+w>" = "rl-filename-rubout";
        "<Alt+Backspace>" = "rl-backward-kill-word";
        "<Ctrl+y>" = "rl-yank";
        "<Ctrl+?>" = "rl-delete-char";
        "<Ctrl+h>" = "rl-backward-delete-char";
        "<Escape>" = "mode-leave";
      };
      hint = {
        "<Return>" = "hint-follow";
        "<Ctrl+r>" = "hint --rapid links tab-bg";
        "<Ctrl+f>" = "hint links";
        "<Ctrl+b>" = "hint all tab-bg";
        "<Escape>" = "mode-leave";
      };
      insert = {
        "<Ctrl+e>" = "edit-text";
        "<Shift+Ins>" = "insert-text -- {primary}";
        "<Escape>" = "mode-leave";
        "<Shift+Escape>" = "fake-key <Escape>";
      };
      passthrough = {
        "<Shift+Escape>" = "mode-leave";
      };
      prompt = {
        "<Return>" = "prompt-accept";
        "<Ctrl+x>" = "prompt-open-download";
        "<Ctrl+p>" = "prompt-open-download --pdfjs";
        "<Shift+Tab>" = "prompt-item-focus prev";
        "<Up>" = "prompt-item-focus prev";
        "<Tab>" = "prompt-item-focus next";
        "<Down>" = "prompt-item-focus next";
        "<Alt+y>" = "prompt-yank";
        "<Alt+Shift+y>" = "prompt-yank --sel";
        "<Alt+e>" = "prompt-fileselect-external";
        "<Ctrl+b>" = "rl-backward-char";
        "<Ctrl+f>" = "rl-forward-char";
        "<Alt+b>" = "rl-backward-word";
        "<Alt+f>" = "rl-forward-word";
        "<Ctrl+a>" = "rl-beginning-of-line";
        "<Ctrl+e>" = "rl-end-of-line";
        "<Ctrl+u>" = "rl-unix-line-discard";
        "<Ctrl+k>" = "rl-kill-line";
        "<Alt+d>" = "rl-kill-word";
        "<Ctrl+w>" = "rl-rubout \" \"";
        "<Ctrl+Shift+w>" = "rl-filename-rubout";
        "<Alt+Backspace>" = "rl-backward-kill-word";
        "<Ctrl+?>" = "rl-delete-char";
        "<Ctrl+h>" = "rl-backward-delete-char";
        "<Ctrl+y>" = "rl-yank";
        "<Escape>" = "mode-leave";
      };
      register = {
        "<Escape>" = "mode-leave";
      };
      yesno = {
        "<Return>" = "prompt-accept";
        "y" = "prompt-accept yes";
        "n" = "prompt-accept no";
        "Y" = "prompt-accept --save yes";
        "N" = "prompt-accept --save no";
        "<Alt+y>" = "prompt-yank";
        "<Alt+Shift+y>" = "prompt-yank --sel";
        "<Escape>" = "mode-leave";
      };
    };
    extendedKeyBindings = {
      normal = {
        "<Ctrl+q>" = "quit";
        "ZQ" = "quit";
        "ZZ" = "quit --save";
        "q" = "macro-record";
        "@" = "macro-run";
        "<F5>" = "reload";
        "<Ctrl+F5>" = "reload -f";
        "m" = "quickmark-save";
        "M" = "bookmark-add";
        "gb" = "cmd-set-text -s :bookmark-load";
        "gB" = "cmd-set-text -s :bookmark-load -t";
        "wB" = "cmd-set-text -s :bookmark-load -w";
        "Sb" = "bookmark-list --jump";
        "Sq" = "bookmark-list";
      };
      caret = { };
      command = { };
      hint = { };
      insert = { };
      passthrough = { };
      prompt = { };
      register = { };
      yesno = { };
    };
    enableExtendedKeyBindings = false;
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
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      defaultSearch =
        if self.settings.privacySearch then
          if self.settings.startpageAsPrivacySearch then
            "https://www.startpage.com/sp/search?q="
          else
            "https://duckduckgo.com/?q="
        else
          "https://${self.settings.googleDomain}/search?q=";

      homeUrl =
        if self.settings.home != null then
          self.settings.home
        else if self.settings.privacySearch then
          if self.settings.startpageAsPrivacySearch then
            "https://www.startpage.com"
          else
            "https://duckduckgo.com"
        else
          "https://${self.settings.googleDomain}";

      userAgent = "Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version_short} Safari/{webkit_version}";
      spoofedUserAgent = "Mozilla/5.0 ({os_info}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36";

      keepassxcKeyBindings =
        if
          (
            self.user.gpg != null
            && self.user.gpg != ""
            && (self.isModuleEnabled "passwords.keepassxc" || self.settings.alwaysCreateKeepassxcKeybindings)
          )
        then
          {
            normal = {
              "pw" = "spawn --userscript qute-keepassxc --key ${self.user.gpg}";
            };
            insert = {
              "<Alt-Shift-u>" = "spawn --userscript qute-keepassxc --key ${self.user.gpg}";
            };
          }
        else
          { };

      mergedKeyBindings = lib.recursiveUpdate (lib.recursiveUpdate (lib.recursiveUpdate self.settings.keyBindings (lib.optionalAttrs self.settings.enableExtendedKeyBindings self.settings.extendedKeyBindings)) self.settings.additionalKeyBindings) keepassxcKeyBindings;

      flattenBookmarks =
        let
          flattenBookmarksRecursive =
            prefix: bookmarks:
            lib.concatMapAttrs (
              name: value:
              let
                safeName = builtins.replaceStrings [ "/" ] [ "-" ] name;
                fullName = if prefix == "" then safeName else "${prefix}/${safeName}";
              in
              if builtins.isString value then
                { "${fullName}" = value; }
              else if builtins.isAttrs value then
                if builtins.length (builtins.attrNames value) > 0 then
                  flattenBookmarksRecursive fullName value
                else
                  { }
              else
                throw "Bookmark value must be either a string (URL) or attribute set (folder)"
            ) bookmarks;
        in
        flattenBookmarksRecursive "";
    in
    {
      programs.qutebrowser = {
        enable = true;
        package = lib.mkDefault pkgs-unstable.qutebrowser;

        loadAutoconfig = false;
        enableDefaultBindings = false;

        settings = {
          confirm_quit =
            if self.settings.askOnQuit then
              [
                "always"
              ]
            else
              [ "downloads" ];
          new_instance_open_target = "tab";
          new_instance_open_target_window = "last-focused";
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
            title_format = "{audio} {current_title} ({host}) {private}";
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
            local_content_can_access_remote_urls = true;
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
              user_agent = if self.settings.spoofUserAgent then spoofedUserAgent else userAgent;
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
            mode_on_change = "restore";
          };
          messages = {
            timeout = 1500;
          };
          scrolling = {
            smooth = true;
            bar = "when-searching";
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
            convertSearchEngines =
              searchEngines:
              lib.mapAttrs' (name: url: lib.nameValuePair "/${name}" url) searchEngines // searchEngines;
          in
          convertSearchEngines (
            {
              search = defaultSearch + "{}";
              google = "https://${self.settings.googleDomain}/search?q={}";
            }
            // lib.optionalAttrs self.settings.addAmazon {
              amazon = "https://${self.settings.amazonDomain}/s?k={}";
            }
            // lib.optionalAttrs self.settings.startpageAsPrivacySearch {
              start = "https://www.startpage.com/sp/search?q={}";
            }
            // lib.optionalAttrs (!self.settings.startpageAsPrivacySearch) {
              duck = "https://duckduckgo.com/?q={}";
            }
            // self.settings.baseSearchEngines
            // self.settings.additionalSearchEngines
          )
          // {
            DEFAULT = defaultSearch + "{}";
          };

        quickmarks =
          let
            convertQuickmarks =
              quickmarks: lib.mapAttrs' (name: url: lib.nameValuePair "@${name}" url) quickmarks;
          in
          convertQuickmarks (
            {
              home = homeUrl;
              google = "https://${self.settings.googleDomain}";
            }
            // lib.optionalAttrs self.settings.addAmazon {
              amazon = "https://${self.settings.amazonDomain}";
            }
            // lib.optionalAttrs self.settings.startpageAsPrivacySearch {
              start = "https://www.startpage.com";
            }
            // lib.optionalAttrs (!self.settings.startpageAsPrivacySearch) {
              duck = "https://duckduckgo.com";
            }
            // self.settings.baseBookmarks
            // (flattenBookmarks self.settings.bookmarks)
          )
          // {
            home = homeUrl;
          };

        aliases =
          let
            flattenedBookmarks = flattenBookmarks self.settings.bookmarks;

            extractFolderPaths =
              let
                allKeys = builtins.attrNames flattenedBookmarks;
                getAllPrefixes =
                  keys:
                  let
                    extractFromKey =
                      key:
                      let
                        parts = lib.splitString "/" key;
                        generatePrefixes =
                          partsList: acc:
                          if (builtins.length partsList) <= 1 then
                            acc
                          else
                            let
                              prefix = builtins.concatStringsSep "/" (lib.take ((builtins.length partsList) - 1) partsList);
                            in
                            [ prefix ] ++ (generatePrefixes (lib.init partsList) acc);
                      in
                      if (builtins.length parts) > 1 then generatePrefixes parts [ ] else [ ];
                    allPrefixes = lib.concatMap extractFromKey keys;
                  in
                  lib.unique allPrefixes;
              in
              getAllPrefixes allKeys;

            folderPaths = extractFolderPaths;

            getMatchingBookmarks =
              pattern: lib.filterAttrs (name: url: lib.hasPrefix pattern name) flattenedBookmarks;

            generateOpenCommand =
              mode: urls:
              let
                urlList = lib.attrValues urls;
                generateCommandString =
                  if mode == "tab" then
                    let
                      firstUrl = lib.head urlList;
                      restUrls = lib.tail urlList;
                      firstCommand = "open -t ${firstUrl}";
                      restCommands = map (url: "open -b ${url}") restUrls;
                    in
                    builtins.concatStringsSep " ;; " ([ firstCommand ] ++ restCommands)
                  else if mode == "background" then
                    let
                      commands = map (url: "open -b ${url}") urlList;
                    in
                    builtins.concatStringsSep " ;; " commands
                  else
                    throw "Invalid bookmark mode, only ['tab', 'background']";
              in
              if mode == "window" then
                if self.isDarwin then
                  "spawn --detach sh -c \\\"open -n -a qutebrowser --args ':${generateCommandString}'\\\""
                else
                  "spawn --detach sh -c \\\"qutebrowser ':${generateCommandString}'\\\""
              else
                generateCommandString;

            generateFolderAliases =
              folderPath:
              let
                matchingBookmarks = lib.filterAttrs (
                  name: url: lib.hasPrefix "${folderPath}/" name || name == folderPath
                ) flattenedBookmarks;
              in
              lib.optionalAttrs (builtins.length (builtins.attrNames matchingBookmarks) > 0) {
                "fg-group#${folderPath}" = generateOpenCommand "tab" matchingBookmarks;
                "bg-group#${folderPath}" = generateOpenCommand "background" matchingBookmarks;
              };

            allFolderAliases = lib.foldl' (
              acc: folderPath: acc // (generateFolderAliases folderPath)
            ) { } folderPaths;
          in
          allFolderAliases // self.settings.additionalAliases;

        keyMappings =
          { }
          // lib.optionalAttrs self.isLinux {
            "~" = "<Shift-Escape>";
          }
          // self.settings.additionalKeyMappings;

        keyBindings = mergedKeyBindings;

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
                  qutebrowser --target window "${defaultSearch}$query"
                fi
              '';
              hotkey-overlay.title = "Apps:Web Search";
            };
          };

          window-rules = [
            {
              matches = [ { app-id = "org.qutebrowser.qutebrowser"; } ];
              open-on-workspace = "2";
            }
          ];
        };
      };
    };
}
