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
  name = "web-app-qutebrowser";

  defaults = {
    persistenceDirs = [
      ".local/state/web-apps"
    ];
    persistenceFiles = [
    ];
  };

  assertions = [
    {
      assertion = self.linux.isModuleEnabled "browser.qutebrowser";
      message = "web-app-qutebrowser requires the qutebrowser module to be enabled in linux namespace";
    }
  ];

  custom = {
    buildWebApp =
      webAppSettings:
      context@{ config, options, ... }:
      let
        webAppUrl = "${webAppSettings.protocol}://${webAppSettings.subdomain}.${webAppSettings.domain}${webAppSettings.args}";
        appName = webAppSettings.webapp;
        dataDir = ".local/state/web-apps/${appName}";
        configPath = ".config/qutebrowser/web-app-${appName}-config.py";

        webAppConfig = ''
          import os

          config.source(os.path.expanduser("~/.config/qutebrowser/config.py"))

          c.bindings.default = {}
          c.bindings.commands = {
              'normal': {
                  'q': 'close',
                  'r': 'reload',
                  'R': 'reload -f',
                  'f': 'hint',
                  'F': 'hint all tab',
                  'j': 'scroll down',
                  'k': 'scroll up',
                  'h': 'scroll left',
                  'l': 'scroll right',
                  'gg': 'scroll-to-perc 0',
                  'G': 'scroll-to-perc',
                  'u': 'undo',
                  'yy': 'yank',
                  '<Escape>': 'clear-keychain ;; search ;; fullscreen --leave',
                  '<F11>': 'fullscreen',
                  '<Ctrl+f>': 'scroll-page 0 1',
                  '<Ctrl+b>': 'scroll-page 0 -1',
                  '<Ctrl+d>': 'scroll-page 0 0.5',
                  '<Ctrl+u>': 'scroll-page 0 -0.5',
                  'i': 'mode-enter insert',
                  'v': 'mode-enter caret',
                  '/': 'cmd-set-text /',
                  'n': 'search-next',
                  'N': 'search-prev',
                  'd': 'tab-close',
                  '<Ctrl+q>': 'tab-close',
                  '<Ctrl+w>': 'tab-close',
                  'J': 'tab-next',
                  'K': 'tab-prev',
                  'gt': 'tab-next',
                  'gT': 'tab-prev',
                  '<Ctrl+Tab>': 'tab-next',
                  '<Ctrl+Shift+Tab>': 'tab-prev',
                  '<Alt+Tab>': 'tab-next',
                  '<Alt+Shift+Tab>': 'tab-prev',
                  '<Ctrl+PgDown>': 'tab-next',
                  '<Ctrl+PgUp>': 'tab-prev',
                  '<Alt+1>': 'tab-focus 1',
                  '<Alt+2>': 'tab-focus 2',
                  '<Alt+3>': 'tab-focus 3',
                  '<Alt+4>': 'tab-focus 4',
                  '<Alt+5>': 'tab-focus 5',
                  '<Alt+6>': 'tab-focus 6',
                  '<Alt+7>': 'tab-focus 7',
                  '<Alt+8>': 'tab-focus 8',
                  '<Alt+9>': 'tab-focus -1',
                  '<Ctrl+1>': 'tab-focus 1',
                  '<Ctrl+2>': 'tab-focus 2',
                  '<Ctrl+3>': 'tab-focus 3',
                  '<Ctrl+4>': 'tab-focus 4',
                  '<Ctrl+5>': 'tab-focus 5',
                  '<Ctrl+6>': 'tab-focus 6',
                  '<Ctrl+7>': 'tab-focus 7',
                  '<Ctrl+8>': 'tab-focus 8',
                  '<Ctrl+9>': 'tab-focus -1',
                  '-': 'zoom-out',
                  '+': 'zoom-in',
                  '=': 'zoom',
                  '<Ctrl+a>': 'navigate increment',
                  '<Ctrl+x>': 'navigate decrement',
                  '<Ctrl+s>': 'stop',
                  '<F5>': 'reload',
                  '<Ctrl+F5>': 'reload -f',
              },
              'insert': {
                  '<Escape>': 'mode-leave',
                  '<Shift+Escape>': 'fake-key <Escape>',
                  '<Ctrl+e>': 'edit-text',
                  '<Shift+Ins>': 'insert-text -- {primary}',
              },
              'caret': {
                  '<Escape>': 'mode-leave',
                  'y': 'yank selection',
                  'j': 'move-to-next-line',
                  'k': 'move-to-prev-line',
                  'h': 'move-to-prev-char',
                  'l': 'move-to-next-char',
              },
              'hint': {
                  '<Escape>': 'mode-leave',
                  '<Return>': 'hint-follow',
              },
              'yesno': {
                  '<Return>': 'prompt-accept',
                  'y': 'prompt-accept yes',
                  'n': 'prompt-accept no',
                  'Y': 'prompt-accept --save yes',
                  'N': 'prompt-accept --save no',
                  '<Alt+y>': 'prompt-yank',
                  '<Alt+Shift+y>': 'prompt-yank --sel',
                  '<Escape>': 'mode-leave',
              },
          }

          c.url.start_pages = ["${webAppUrl}"]
          c.url.default_page = "${webAppUrl}"
          c.aliases = {}
          c.spellcheck.languages = []
          c.auto_save.session = False
          c.window.title_format = "${webAppSettings.name}"
          c.statusbar.widgets = ["keypress"]
          c.confirm_quit = ["never"]
          c.tabs.show = "multiple"
          c.new_instance_open_target = "tab-silent"
          c.new_instance_open_target_window = "last-focused"
        '';
      in
      {
        home.file.".local/bin/${appName}-webapp" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            exec ${pkgs-unstable.qutebrowser}/bin/qutebrowser \
              --target window \
              --basedir "${config.home.homeDirectory}/${dataDir}" \
              --config-py "${config.home.homeDirectory}/${configPath}" \
              "${webAppUrl}"
          '';
        };

        home.file."${configPath}" = {
          text = webAppConfig;
        };

        xdg.desktopEntries = {
          "${appName}" = {
            name = webAppSettings.name;
            comment = "${webAppSettings.name} Web-App (Qutebrowser)";
            exec = "${config.home.homeDirectory}/.local/bin/${appName}-webapp %U";
            icon = webAppSettings.iconPath;
            terminal = false;
            categories = webAppSettings.categories;
          };
        };
      };
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.persistence."${self.persist}" = {
        directories = self.settings.persistenceDirs;
        files = self.settings.persistenceFiles;
      };
    };
}
