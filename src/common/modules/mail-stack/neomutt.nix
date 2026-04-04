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
  name = "neomutt";
  group = "mail-stack";
  input = "common";

  submodules = {
    common = {
      mail-stack = {
        accounts = true;
        mbsync = true;
        msmtp = true;
        notmuch = true;
      };
    };
  };

  settings = {
    unbindDefaultKeys = true;
    dateFormat = "%d.%m.%y %T";

    additionalMimeMappings = { };

    keybinds = {
      generic = {
        "<Return>" = "select-entry";
        ";" = "enter-command";
        "?" = "help";
        "q" = "exit";
        "\\CD" = "half-down";
        "\\CU" = "half-up";
        "<PageDown>" = "half-down";
        "<PageUp>" = "half-up";
      };
      alias = {
        "?" = "help";
        "<Esc>" = "exit";
        "q" = "exit";
      };
      attach = {
        "?" = "help";
        "<Esc>" = "exit";
        "q" = "exit";
        "j" = "next-entry";
        "k" = "previous-entry";
        "<Down>" = "next-entry";
        "<Up>" = "previous-entry";
        "m" = "view-attach";
        "<Return>" = "view-mailcap";
        "\\Cb" = {
          command = "<pipe-entry> urlscan-neomutt<Enter>";
          description = "Extract URLs from attachment";
        };
        "V" = {
          command = "<shell-escape>rm -f ~/.cache/neomutt/temp-mail.html<enter><pipe-entry>cat > ~/.cache/neomutt/temp-mail.html<enter><shell-escape>${
            if self.isDarwin then "${pkgs.darwin.system_cmds}/bin/open" else "${pkgs.xdg-utils}/bin/xdg-open"
          } ~/.cache/neomutt/temp-mail.html<enter>";
          description = "Open HTML attachment in browser";
        };
      };
      browser = {
        "?" = "help";
        "<Esc>" = "exit";
        "q" = "exit";
        "j" = "next-entry";
        "k" = "previous-entry";
        "<Down>" = "next-entry";
        "<Up>" = "previous-entry";
      };
      editor = {
        "<Backspace>" = "backspace";
        "\\177" = "backspace";
      };
      index = {
        "<Return>" = "display-message";
        "?" = "help";
        "j" = "next-entry";
        "k" = "previous-entry";
        "<Down>" = "next-entry";
        "<Up>" = "previous-entry";
        "<Tab>" = "next-new-then-unread";
        "gg" = "first-entry";
        "G" = "last-entry";
        "n" = "search-next";
        "N" = "search-opposite";
        "/" = "search";
        "*" = "tag-entry";
        "u" = "undelete-message";
        "r" = "reply";
        "R" = "group-reply";
        "f" = "forward-message";
        "m" = "save-message";
        "l" = "limit";
        "T" = "modify-labels";
        "E" = "entire-thread";
        "." = "vfolder-from-query";
        "c" = "mail";
        "<C-J>" = "sidebar-next";
        "<C-K>" = "sidebar-prev";
        "<C-Down>" = "sidebar-next";
        "<C-Up>" = "sidebar-prev";
        "\\CO" = "sidebar-open";
        "M" = "sidebar-toggle-visible";
        "$" = {
          command = "<shell-escape>~/.local/bin/scripts/neomutt-print-header.sh mbsync-fetch-mail<enter><change-folder>^<enter>";
          description = "Sync mail + refresh";
        };
        "%" = {
          command = "<shell-escape>~/.local/bin/scripts/neomutt-print-header.sh --notmuch ~/.local/bin/scripts/notmuch-process-mails.sh --move-first<enter><change-folder>^<enter>";
          description = "Process existing mail";
        };
        "<Space>" = {
          command = "<change-folder>?";
          description = "Change folder with browser";
        };
        "q" = {
          command = "<change-folder>^<enter>";
          description = "Refresh current folder";
        };
        "<Esc>" = {
          command = "<change-folder>^<enter>";
          description = "Refresh current folder";
        };
        "aa" = {
          command = "<modify-labels>-sent -drafts -trash -inbox -spam +archive<enter>";
          description = "Archive message";
        };
        "ii" = {
          command = "<modify-labels>-sent -drafts -trash -archive -spam +inbox<enter>";
          description = "Move to inbox";
        };
        "dd" = {
          command = "<modify-labels>-inbox -sent -drafts -archive -spam +trash<enter>";
          description = "Move to trash";
        };
        "DD" = {
          command = "<modify-labels>-inbox -sent -trash -archive -spam +drafts<enter>";
          description = "Move to drafts";
        };
        "SS" = {
          command = "<modify-labels>-inbox -sent -drafts -trash -archive +spam<enter>";
          description = "Move to spam";
        };
        "ss" = {
          command = "<modify-labels>-inbox -drafts -trash -archive -spam +sent<enter>";
          description = "Move to sent";
        };
        "\\Cb" = {
          command = "<pipe-message> urlscan-neomutt<Enter>";
          description = "Extract URLs from message";
        };
      };
      compose = {
        "?" = "help";
        "<Esc>" = "exit";
        "q" = "exit";
        "e" = "edit-message";
        "E" = "edit-headers";
        "s" = "edit-subject";
        "t" = "edit-to";
        "c" = "edit-cc";
        "b" = "edit-bcc";
        "f" = "edit-fcc";
        "a" = "attach-file";
        "yy" = "send-message";
        "pp" = "postpone-message";
        "\\Cb" = {
          command = "<pipe-entry> urlscan-neomutt<Enter>";
          description = "Extract URLs from composition";
        };
      };
      pager = {
        "?" = "help";
        "<Esc>" = "exit";
        "q" = "exit";
        ";" = "enter-command";
        "j" = "next-line";
        "k" = "previous-line";
        "<Down>" = "next-line";
        "<Up>" = "previous-line";
        "<Space>" = "next-page";
        "<Enter>" = "exit";
        "n" = "search-next";
        "N" = "search-opposite";
        "/" = "search";
        "r" = "reply";
        "R" = "group-reply";
        "f" = "forward-message";
        "v" = "view-attachments";
        "h" = "display-toggle-weed";
        "<C-J>" = "sidebar-next";
        "<C-K>" = "sidebar-prev";
        "<C-Down>" = "sidebar-next";
        "<C-Up>" = "sidebar-prev";
        "\\CO" = "sidebar-open";
        "M" = "sidebar-toggle-visible";
        "\\Cb" = {
          command = "<pipe-message> urlscan-neomutt<Enter>";
          description = "Extract URLs from message";
        };
      };
      pgp = {
        "?" = "help";
        "<Esc>" = "exit";
        "q" = "exit";
      };
      smime = {
        "?" = "help";
        "<Esc>" = "exit";
        "q" = "exit";
      };
      postpone = {
        "?" = "help";
        "<Esc>" = "exit";
        "q" = "exit";
      };
      query = {
        "?" = "help";
        "<Esc>" = "exit";
        "q" = "exit";
      };
    };

    colors = null;
  };

  on = {
    home =
      config:
      let
        theme = config.nx.preferences.theme;
        terminal = config.nx.preferences.desktop.programs.additionalTerminal;
        terminalRunWithClass =
          class: cmd:
          lib.escapeShellArgs (
            helpers.runWithAbsolutePath config terminal (terminal.openRunWithClass class) cmd
          );
        defaultColors = {
          normal = {
            fg = theme.colors.terminal.colors.green.html;
            bg = "default";
          };
          error = {
            fg = theme.colors.terminal.colors.red.html;
            bg = "default";
          };
          message = {
            fg = theme.colors.terminal.colors.cyan.html;
            bg = "default";
          };
          indicator = {
            fg = theme.colors.terminal.normalBackgrounds.primary.html;
            bg = theme.colors.terminal.colors.green.html;
          };
          tree = {
            fg = theme.colors.terminal.foregrounds.dim.html;
            bg = "default";
          };
          index = {
            fg = theme.colors.terminal.colors.green.html;
            bg = "default";
          };
          index_author = {
            fg = theme.colors.terminal.colors.cyan.html;
            bg = "default";
          };
          index_subject = {
            fg = theme.colors.terminal.colors.green.html;
            bg = "default";
          };
          index_date = {
            fg = theme.colors.terminal.colors.yellow.html;
            bg = "default";
          };
          index_new = {
            fg = theme.colors.terminal.colors.yellow.html;
            bg = "default";
          };
          index_deleted = {
            fg = theme.colors.terminal.colors.red.html;
            bg = "default";
          };
          index_tagged = {
            fg = theme.colors.terminal.colors.cyan.html;
            bg = "default";
          };
          index_flagged = {
            fg = theme.colors.terminal.colors.green.html;
            bg = "default";
          };
          header_from = {
            fg = theme.colors.terminal.colors.cyan.html;
            bg = "default";
          };
          header_to = {
            fg = theme.colors.terminal.colors.cyan.html;
            bg = "default";
          };
          header_subject = {
            fg = theme.colors.terminal.colors.yellow.html;
            bg = "default";
          };
          header_date = {
            fg = theme.colors.terminal.colors.yellow.html;
            bg = "default";
          };
          quoted = {
            fg = theme.colors.terminal.colors.cyan.html;
            bg = "default";
          };
          quoted1 = {
            fg = theme.colors.terminal.colors.green.html;
            bg = "default";
          };
          quoted2 = {
            fg = theme.colors.terminal.colors.yellow.html;
            bg = "default";
          };
          signature = {
            fg = theme.colors.terminal.foregrounds.dim.html;
            bg = "default";
          };
          bold = {
            fg = theme.colors.terminal.colors.green.html;
            bg = "default";
          };
          tilde = {
            fg = theme.colors.terminal.foregrounds.dim.html;
            bg = "default";
          };
          markers = {
            fg = theme.colors.terminal.colors.yellow.html;
            bg = "default";
          };
          attachment = {
            fg = theme.colors.terminal.colors.cyan.html;
            bg = "default";
          };
          search = {
            fg = theme.colors.terminal.normalBackgrounds.primary.html;
            bg = theme.colors.terminal.colors.yellow.html;
          };
          status = {
            fg = theme.colors.terminal.colors.cyan.html;
            bg = "default";
          };
          index_tags = {
            fg = theme.colors.terminal.colors.yellow.html;
            bg = "default";
          };
          sidebar_background = {
            fg = "default";
            bg = "default";
          };
          sidebar_indicator = {
            fg = theme.colors.terminal.normalBackgrounds.primary.html;
            bg = theme.colors.terminal.colors.green.html;
          };
          sidebar_highlight = {
            fg = theme.colors.terminal.colors.green.html;
            bg = theme.colors.terminal.normalBackgrounds.secondary.html;
          };
          sidebar_spool_file = {
            fg = theme.colors.terminal.colors.yellow.html;
            bg = "default";
          };
          sidebar_unread = {
            fg = theme.colors.terminal.colors.cyan.html;
            bg = "default";
          };
          sidebar_new = {
            fg = theme.colors.terminal.colors.green.html;
            bg = "default";
          };
          sidebar_ordinary = {
            fg = "default";
            bg = "default";
          };
          sidebar_flagged = {
            fg = theme.colors.terminal.colors.red.html;
            bg = "default";
          };
          sidebar_divider = {
            fg = theme.colors.terminal.foregrounds.dim.html;
            bg = "default";
          };
        };
        colors = if self.settings.colors != null then self.settings.colors else defaultColors;

        isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
        appLauncher = config.nx.preferences.desktop.programs.appLauncher;
        hasAppLauncher = appLauncher != null;

        accountsConfig = self.getModuleConfig "mail-stack.accounts";
        accounts = accountsConfig.accounts;
        accountKeys = lib.attrNames accounts;

        defaultAccountKey = lib.findFirst (
          name: accounts.${name}.default or false
        ) (lib.head accountKeys) accountKeys;

        baseDataDir = "${config.xdg.dataHome}/${accountsConfig.baseDataDir}";
        mailDir = "${baseDataDir}/${accountsConfig.maildirPath}";

        cacheDir = "${config.xdg.cacheHome}/neomutt";

        generateUnbind = context: key: "unbind ${context} ${key}";

        customPkgs = self.pkgs {
          overlays = [
            (final: prev: {
              neomutt = prev.neomutt.overrideAttrs (oldAttrs: {
                nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
                  prev.makeWrapper
                ];
                postFixup = oldAttrs.postFixup or "" + ''
                  wrapProgram $out/bin/neomutt \
                    --set TERM "xterm-direct"
                '';
              });
            })
          ];
        };

        generateBinds =
          context: binds:
          let
            genericUnbindString = "unbind ${context} *";

            allKeyUnbinds = lib.concatStringsSep "\n" (
              let
                stringToChars =
                  s: lib.lists.map (i: builtins.substring i 1 s) (lib.lists.range 0 (builtins.stringLength s - 1));

                lowercase = stringToChars "abcdefghijklmnopqrstuvwxyz";
                uppercase = stringToChars "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
                digits = stringToChars "0123456789";

                safeSpecials = stringToChars "!$%&()*+,-./:=?@{|}~#";

                namedSpecials = [
                  "<space>"
                  "<tab>"
                  "<backtab>"
                  "<enter>"
                  "<return>"
                  "<esc>"
                  "<backspace>"
                  "<insert>"
                  "<delete>"
                  "<up>"
                  "<down>"
                  "<left>"
                  "<right>"
                  "<home>"
                  "<end>"
                  "<pageup>"
                  "<pagedown>"
                  "<f1>"
                  "<f2>"
                ];

                keysWithPrefixes = lowercase ++ uppercase ++ digits;

                prefixes = [
                  "<esc>"
                  "\\C"
                ];

                directKeys = lib.map (key: generateUnbind context key) (
                  lowercase ++ uppercase ++ digits ++ safeSpecials ++ namedSpecials
                );

                prefixedKeys = lib.concatLists (
                  lib.map (key: lib.map (prefix: generateUnbind context "${prefix}${key}") prefixes) keysWithPrefixes
                );

                baseKeyUnbinds = [
                  (generateUnbind context "<Esc>")
                ];

                escapeAlphabetConflicts = lib.concatLists [
                  (lib.map (c: generateUnbind context "<Esc>${c}") (stringToChars "abcdefghijklmnopqrstuvwxyz"))
                  (lib.map (c: generateUnbind context "<Esc>${c}") (stringToChars "ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
                ];

                conflictResolution = [
                  (generateUnbind context "<Esc>/")
                  (generateUnbind context "<Esc>?")
                  (generateUnbind context "<Esc><Tab>")
                ]
                ++ escapeAlphabetConflicts;
              in
              conflictResolution ++ baseKeyUnbinds ++ directKeys ++ prefixedKeys
            );

            bindStrings = lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                key: action:
                let
                  escapedKey = if lib.hasPrefix "\\C" key then key else lib.escapeShellArg key;
                in
                "bind ${context} ${escapedKey} ${action}"
              ) binds
            );
          in
          lib.concatStringsSep "\n" (
            lib.optionals (self.settings.unbindDefaultKeys or false) [
              genericUnbindString
              allKeyUnbinds
            ]
            ++ [
              (if bindStrings == "" then "" else bindStrings)
            ]
          );

        generateColors =
          colors:
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              name: colorDef:
              if name == "index_new" then
                "color index ${colorDef.fg} ${colorDef.bg} \"~N\""
              else if name == "index_deleted" then
                "color index ${colorDef.fg} ${colorDef.bg} \"~D\""
              else if name == "index_tagged" then
                "color index ${colorDef.fg} ${colorDef.bg} \"~T\""
              else if name == "index_flagged" then
                "color index ${colorDef.fg} ${colorDef.bg} \"~F\""
              else if name == "header_from" then
                "color header ${colorDef.fg} ${colorDef.bg} \"^From:\""
              else if name == "header_to" then
                "color header ${colorDef.fg} ${colorDef.bg} \"^To:\""
              else if name == "header_subject" then
                "color header ${colorDef.fg} ${colorDef.bg} \"^Subject:\""
              else if name == "header_date" then
                "color header ${colorDef.fg} ${colorDef.bg} \"^Date:\""
              else
                "color ${name} ${colorDef.fg} ${colorDef.bg}"
            ) colors
          );

        generateMacros =
          macros:
          lib.concatStringsSep "\n" (
            lib.concatLists (
              lib.mapAttrsToList (
                context: contextMacros:
                lib.mapAttrsToList (
                  key: macroDef:
                  let
                    escapedKey = if lib.hasPrefix "\\C" key then key else lib.escapeShellArg key;
                  in
                  "macro ${context} ${escapedKey} ${lib.escapeShellArg macroDef.command} ${lib.escapeShellArg macroDef.description}"
                ) contextMacros
              ) macros
            )
          );

        isMacro =
          action:
          if builtins.isAttrs action then true else (lib.hasInfix "<" action) || (lib.hasInfix " " action);

        separateKeybinds =
          keybinds:
          lib.foldlAttrs
            (
              acc: context: contextKeybinds:
              lib.foldlAttrs (
                innerAcc: key: action:
                if isMacro action then
                  innerAcc
                  // {
                    macros = innerAcc.macros // {
                      ${context} = (innerAcc.macros.${context} or { }) // {
                        ${key} =
                          if builtins.isAttrs action then
                            action
                          else
                            {
                              command = action;
                              description = "";
                            };
                      };
                    };
                  }
                else
                  innerAcc
                  // {
                    binds = innerAcc.binds // {
                      ${context} = (innerAcc.binds.${context} or { }) // {
                        ${key} = action;
                      };
                    };
                  }
              ) acc contextKeybinds
            )
            {
              binds = { };
              macros = { };
            }
            keybinds;

        separated = separateKeybinds self.settings.keybinds;
        binds = separated.binds;
        macros = separated.macros;
      in
      {
        programs.neomutt = {
          enable = true;
          package = lib.mkForce customPkgs.neomutt;

          settings = {
            folder = mailDir;

            sort = "threads";
            sort_aux = "reverse-date";
            pager_index_lines = "10";
            pager_context = "3";
            menu_scroll = "yes";

            quit = "no";
            delete = "yes";

            nm_default_url = "notmuch://${mailDir}";
            nm_db_limit = "0";
            virtual_spoolfile = "no";

            header_cache = cacheDir;
            message_cachedir = cacheDir;
            tmpdir = "${cacheDir}/temp";

            color_directcolor = "yes";

            sidebar_visible = "yes";
            sidebar_width = "35";
            sidebar_sort_method = "unsorted";
            sidebar_divider_char = "┊";
            mail_check_stats = "yes";

            sleep_time = "0";

            edit_headers = "yes";
            include = "yes";
            pager_stop = "yes";
            reply_to = "yes";

            send_charset = "utf-8";
            assumed_charset = "utf-8";
          };

          extraConfig = ''
            virtual-mailboxes "📬 Combined Inbox" "notmuch://?query=tag%3Ainbox&type=messages"
            virtual-mailboxes "📦 Archive" "notmuch://?query=tag%3Aarchive&type=messages"
            virtual-mailboxes "📤 Sent" "notmuch://?query=tag%3Asent&type=messages"
            virtual-mailboxes "📝 Drafts" "notmuch://?query=tag%3Adrafts&type=messages"
            virtual-mailboxes "🗑️ Trash" "notmuch://?query=tag%3Atrash&type=messages"
            virtual-mailboxes "🚫 Spam" "notmuch://?query=tag%3Aspam&type=messages"
            virtual-mailboxes "📧 All Mails" "notmuch://?query=%2A&type=messages"

            ${lib.concatMapStringsSep "\n" (accountKey: ''
              virtual-mailboxes "(All Mail) ${accountKey}" "notmuch://?query=tag%3A${accountKey}&type=messages"
            '') accountKeys}

            ${lib.concatMapStringsSep "\n"
              (mailbox: ''
                virtual-mailboxes "+${mailbox.name}" "notmuch://?query=${lib.escapeURL mailbox.query}&type=messages"
              '')
              (
                if self.isModuleEnabled "mail-stack.notmuch" then
                  (self.getModuleConfig "mail-stack.notmuch").virtualMailboxes
                else
                  [ ]
              )
            }

            ${lib.concatMapStringsSep "\n" (
              accountKey:
              let
                account = accounts.${accountKey};
                accountVirtualMailboxes = account.virtualMailboxes or [ ];
              in
              lib.concatMapStringsSep "\n" (mailbox: ''
                virtual-mailboxes "[${accountKey}] ${mailbox.name}" "notmuch://?query=${lib.escapeURL "path:${accountKey}/** AND (${mailbox.query})"}&type=messages"
              '') accountVirtualMailboxes
            ) accountKeys}

            set spoolfile = "📬 Combined Inbox"
            set index_format = "%4C %Z %{%b %d} %-15.15L (%?l?%4l&%4c?) %s │ %g"
            set sidebar_format = "%D%?F? [%F]?%* %?N?%N/?%S"
            set date_format = "${self.settings.dateFormat}"

            ${lib.concatStringsSep "\n" (lib.mapAttrsToList generateBinds binds)}

            ${generateMacros macros}

            auto_view text/html
            alternative_order text/plain text/enriched text/html

            ${lib.concatMapStringsSep "\n" (
              accountKey:
              let
                account = accounts.${accountKey};
                buildServerConfig =
                  (self.importFileFromOtherModuleSameInput {
                    inherit args self;
                    modulePath = "mail-stack.accounts";
                  }).custom.buildServerConfig;
                serverConfig = buildServerConfig accountKey account;
                folders = serverConfig.folders;
              in
              ''
                mailboxes +${lib.escapeShellArg "${accountKey}/${folders.sent}"} +${lib.escapeShellArg "${accountKey}/${folders.drafts}"} +${lib.escapeShellArg "${accountKey}/${folders.trash}"} +${lib.escapeShellArg "${accountKey}/${folders.archive}"} +${lib.escapeShellArg "${accountKey}/${folders.spam}"}
              ''
            ) accountKeys}

            ${generateColors colors}
          '';
        };

        accounts.email.accounts = lib.mapAttrs (accountKey: account: {
          neomutt = {
            enable = true;
          };
          signature = lib.mkIf (account.signature or null != null) {
            text = account.signature;
          };
        }) accounts;

        home.file.".mailcap".text =
          let
            guiTest = "test -n \"$DISPLAY\" -o -n \"$WAYLAND_DISPLAY\"";

            generateMailcap =
              let
                systemOpen =
                  if self.isLinux then
                    "xdg-open"
                  else if self.isDarwin then
                    "open"
                  else
                    null;
                catProgram = if self.isModuleEnabled "shell.rust-programs" then "bat" else "cat";

                generateMailcapRule =
                  mimeType: command:
                  if self.isDarwin then "${mimeType}; ${command}" else "${mimeType}; ${command}; test=${guiTest}";

                generateDesktopRule =
                  mimeType: lib.optionalString (systemOpen != null) (generateMailcapRule mimeType "${systemOpen} %s");
              in
              ''
                text/html; ${pkgs.w3m}/bin/w3m -o auto_image=TRUE -o display_image=1 -T text/html %s; nametemplate=%s.html; needsterminal
                text/html; ${pkgs.w3m}/bin/w3m -dump -T text/html -cols 80 %s; copiousoutput
                ${lib.optionalString (systemOpen != null)
                  "text/html; ${systemOpen} %s; ${if self.isDarwin then "" else guiTest}; nametemplate=%s.html"
                }

                ${lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (
                    mimeType: command: generateMailcapRule mimeType command
                  ) self.settings.additionalMimeMappings
                )}

                text/*; vim %s; needsterminal
                text/*; ${catProgram} %s; copiousoutput

                ${generateDesktopRule "image/*"}
                ${generateDesktopRule "audio/*"}
                ${generateDesktopRule "video/*"}
                ${generateDesktopRule "application/*"}
                ${generateDesktopRule "model/*"}

                ${lib.optionalString self.isLinux "*/*; echo \"Attachment type: %{type}. Use 'v' to save and open manually.\"; copiousoutput"}
              '';
          in
          generateMailcap;

        home.packages = [
          pkgs.w3m
          pkgs.urlscan
          (pkgs.writeShellScriptBin "urlscan-neomutt" ''
            #!/usr/bin/env bash
            set -euo pipefail

            ${
              if isNiriEnabled && hasAppLauncher then
                let
                  launcherCmd = lib.escapeShellArgs (
                    helpers.runWithAbsolutePath config appLauncher appLauncher.dmenuCommand {
                      prompt = "Select URL: ";
                      width = 80;
                    }
                  );
                in
                ''
                  if [ -z "''${WAYLAND_DISPLAY:-}" ] && [ -z "''${DISPLAY:-}" ]; then
                    exec urlscan "$@"
                  fi

                  URLS=$(urlscan --no-browser --dedupe)

                  if [ -z "$URLS" ]; then
                    echo "No URLs found in message"
                    exit 0
                  fi

                  URL_COUNT=$(echo "$URLS" | wc -l)

                  if [ "$URL_COUNT" -eq 1 ]; then
                    URL="$URLS"
                    xdg-open "$URL" &
                  else
                    URL=$(echo "$URLS" | ${launcherCmd})
                    if [ -n "$URL" ]; then
                      xdg-open "$URL" &
                    fi
                  fi
                ''
              else
                ''
                  exec urlscan "$@"
                ''
            }
          '')
        ];

        home.file.".config/urlscan/config.json" = {
          text = builtins.toJSON {
            palettes = {
              default = [
                [
                  "body"
                  "default"
                  "default"
                ]
                [
                  "foot"
                  "dark cyan"
                  "dark blue"
                ]
                [
                  "head"
                  "yellow"
                  "dark red"
                ]
              ];
            };
            browser = if self.isDarwin then "open" else "xdg-open";
            compact = false;
            dedupe = true;
            nohelp = false;
            run_safe = null;
            single = true;
            pipe = false;
          };
        };

        home.file.".local/bin/neomutt-term" = {
          text = ''
            #!/usr/bin/env bash
            exec ${terminalRunWithClass "org.nx.neomutt" "neomutt"}
          '';
          executable = true;
        };

        home.file.".local/bin/scripts/neomutt-print-header.sh" = {
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            BLUE='\033[0;34m'
            GREEN='\033[0;32m'
            YELLOW='\033[1;33m'
            RED='\033[0;31m'
            RESET='\033[0m'
            BOLD='\033[1m'

            NOTMUCH_MODE=false
            if [ $# -gt 0 ] && [ "$1" = "--notmuch" ]; then
              NOTMUCH_MODE=true
              shift
            fi

            clear
            if [ "$NOTMUCH_MODE" = true ]; then
              echo -e "''${YELLOW}"
              echo "    ███╗   ██╗ ██████╗ ████████╗███╗   ███╗██╗   ██╗ ██████╗██╗  ██╗"
              echo "    ████╗  ██║██╔═══██╗╚══██╔══╝████╗ ████║██║   ██║██╔════╝██║  ██║"
              echo "    ██╔██╗ ██║██║   ██║   ██║   ██╔████╔██║██║   ██║██║     ███████║"
              echo "    ██║╚██╗██║██║   ██║   ██║   ██║╚██╔╝██║██║   ██║██║     ██╔══██║"
              echo "    ██║ ╚████║╚██████╔╝   ██║   ██║ ╚═╝ ██║╚██████╔╝╚██████╗██║  ██║"
              echo "    ╚═╝  ╚═══╝ ╚═════╝    ╚═╝   ╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝"
              echo -e "''${RESET}"
              echo -e "''${YELLOW}╭─────────────────────────────────────────────────────────────────────╮''${RESET}"
              echo -e "''${YELLOW}│''${BOLD}                           Notmuch Overview                          ''${YELLOW}│''${RESET}"
              echo -e "''${YELLOW}╰─────────────────────────────────────────────────────────────────────╯''${RESET}"
            else
              echo -e "''${BLUE}"
              echo "    ███╗   ██╗███████╗ ██████╗ ███╗   ███╗██╗   ██╗████████╗████████╗"
              echo "    ████╗  ██║██╔════╝██╔═══██╗████╗ ████║██║   ██║╚══██╔══╝╚══██╔══╝"
              echo "    ██╔██╗ ██║█████╗  ██║   ██║██╔████╔██║██║   ██║   ██║      ██║   "
              echo "    ██║╚██╗██║██╔══╝  ██║   ██║██║╚██╔╝██║██║   ██║   ██║      ██║   "
              echo "    ██║ ╚████║███████╗╚██████╔╝██║ ╚═╝ ██║╚██████╔╝   ██║      ██║   "
              echo "    ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝ ╚═════╝    ╚═╝      ╚═╝   "
              echo -e "''${RESET}"
              echo -e "''${BLUE}╭─────────────────────────────────────────────────────────────────────╮''${RESET}"
              echo -e "''${BLUE}│''${BOLD}                            Mail Overview                            ''${BLUE}│''${RESET}"
              echo -e "''${BLUE}╰─────────────────────────────────────────────────────────────────────╯''${RESET}"
            fi
            echo

            echo -e "''${GREEN}📬 inbox:   ''${RESET}$(${pkgs.notmuch}/bin/notmuch count -- tag:inbox)"
            echo -e "''${YELLOW}📤 sent:    ''${RESET}$(${pkgs.notmuch}/bin/notmuch count -- tag:sent)"
            echo -e "''${YELLOW}📝 drafts:  ''${RESET}$(${pkgs.notmuch}/bin/notmuch count -- tag:drafts)"
            echo -e "''${BLUE}📦 archive: ''${RESET}$(${pkgs.notmuch}/bin/notmuch count -- tag:archive)"
            echo -e "''${RED}🗑️ trash:   ''${RESET}$(${pkgs.notmuch}/bin/notmuch count -- tag:trash)"
            echo -e "''${RED}🚫 spam:    ''${RESET}$(${pkgs.notmuch}/bin/notmuch count -- tag:spam)"
            echo -e "''${BLUE}─────────────────────────────''${RESET}"
            echo -e "''${BOLD}📊 Total:   ''${RESET}$(${pkgs.notmuch}/bin/notmuch count '*')"
            echo

            if [ $# -eq 0 ]; then
              exit 0
            fi

            echo -e "''${BLUE}⚙️  Running: $*''${RESET}"
            echo
            echo

            EQUALIZER=(
              "▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃"
              "▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅"
              "▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇"
              "▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█"
              "█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇"
              "▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅"
              "▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃"
              "▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁"
              "▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁"
              "▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃▁▁▃▅▇█▇▅▃"
            )
            EQUALIZER_LEN=''${#EQUALIZER[@]}

            TEMP_OUTPUT=$(mktemp)
            START_TIME=$(date +%s)
            TAIL_PID=""

            cleanup() {
              [ -n "$TAIL_PID" ] && kill "$TAIL_PID" 2>/dev/null || true
              [ -n "$CMD_PID" ] && kill "$CMD_PID" 2>/dev/null || true
              rm -f "$TEMP_OUTPUT" 2>/dev/null || true
            }
            trap cleanup EXIT INT TERM

            set +e
            "$@" > "$TEMP_OUTPUT" 2>&1 &
            CMD_PID=$!

            SPINNER_INDEX=0
            while kill -0 "$CMD_PID" 2>/dev/null; do
              CURRENT_TIME=$(date +%s)
              ELAPSED=$((CURRENT_TIME - START_TIME))
              MINUTES=$((ELAPSED / 60))
              SECONDS=$((ELAPSED % 60))
              TIME_DISPLAY=$(printf "%02d:%02d" $MINUTES $SECONDS)
              printf "\r  ''${GREEN}''${EQUALIZER[$SPINNER_INDEX]} ''${BLUE} Processing... ''${RESET}[$TIME_DISPLAY]"
              SPINNER_INDEX=$(( (SPINNER_INDEX + 1) % EQUALIZER_LEN ))
              sleep 0.15

              if [ $ELAPSED -gt 60 ]; then
                printf "\r\033[2K''${RED}⏱️  Taking longer than expected...''${RESET}\n"
                echo
                if [ -s "$TEMP_OUTPUT" ]; then
                  echo -e "''${YELLOW}Output so far:''${RESET}"
                  cat "$TEMP_OUTPUT"
                  echo -e "''${YELLOW}--- Waiting for completion ---''${RESET}"
                else
                  echo -e "''${YELLOW}No output yet, waiting for completion...''${RESET}"
                fi
                wait "$CMD_PID"
                CMD_EXIT=$?
                cleanup
                exit $CMD_EXIT
              fi
            done

            wait "$CMD_PID"
            CMD_EXIT=$?
            set -e

            printf "\r\033[2K"

            if [ $CMD_EXIT -eq 0 ]; then
              echo -e "''${GREEN}✅ Completed successfully''${RESET}"
              echo
            elif [ $CMD_EXIT -eq 143 ]; then
              echo -e "''${YELLOW}⚠️  Cancelled by user (SIGTERM)''${RESET}"
              if [ -f "$TEMP_OUTPUT" ]; then
                echo -e "''${YELLOW}Output:''${RESET}"
                echo
                cat "$TEMP_OUTPUT"
                echo
              fi
            else
              echo -e "''${RED}❌ Command failed (exit code: $CMD_EXIT)''${RESET}"
              echo
              if [ -f "$TEMP_OUTPUT" ]; then
                echo -e "''${RED}Output:''${RESET}"
                echo
                cat "$TEMP_OUTPUT"
                echo
              fi
            fi

            rm -f "$TEMP_OUTPUT"
            exit $CMD_EXIT
          '';
          executable = true;
        };

        programs.niri = lib.mkIf isNiriEnabled {
          settings = {
            binds = with config.lib.niri.actions; {
              "Mod+Ctrl+Alt+O" = {
                action = spawn-sh "niri-scratchpad --app-id org.nx.neomutt --all-windows --spawn neomutt-term";
                hotkey-overlay.title = "Apps:Mails";
              };
            };

            window-rules = [
              {
                matches = [ { app-id = "org.nx.neomutt"; } ];
                min-width = 800;
                min-height = 800;
                open-on-workspace = "scratch";
                open-floating = true;
                open-focused = false;
              }
            ];
          };
        };

        home.persistence."${self.persist}" = {
          directories = [
            (lib.removePrefix "${config.home.homeDirectory}/" cacheDir)
          ];
        };
      };
  };
}
