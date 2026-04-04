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
  kde = pkgs.kdePackages;
  gnome = pkgs;

  mkProgram =
    {
      name,
      package ? null,
      openCommand ? null,
      openFileCommand ? null,
      additionalPackages ? [ ],
      desktopFile ? null,
      dirsToPersist ? [ ],
      filesToPersist ? [ ],
    }:
    let
      nameParts = lib.splitString "." name;
      finalName = lib.last nameParts;
      finalOpenCommand = if openCommand != null then openCommand else [ finalName ];
    in
    {
      inherit
        name
        additionalPackages
        dirsToPersist
        filesToPersist
        ;
      package = package;
      openCommand = finalOpenCommand;
      openFileCommand =
        if openFileCommand != null then openFileCommand else (file: finalOpenCommand ++ [ file ]);
      desktopFile = desktopFile;
    };

  mkTerminal =
    {
      name,
      package ? null,
      openCommand ? null,
      openDirectoryCommand ? null,
      openRunCommand ? null,
      openRunPrefix ? null,
      openShellCommand ? null,
      openWithClass ? null,
      openRunWithClass ? null,
      additionalPackages ? [ ],
      desktopFile ? null,
      dirsToPersist ? [ ],
      filesToPersist ? [ ],
      execFlag ? "-e",
      directoryFlag ? "--working-directory=",
      classFlag ? "--class=",
    }:
    let
      nameParts = lib.splitString "." name;
      finalName = lib.last nameParts;
      finalOpenCommand = if openCommand != null then openCommand else [ finalName ];
    in
    {
      inherit
        name
        additionalPackages
        desktopFile
        dirsToPersist
        filesToPersist
        ;
      package = package;
      openCommand = finalOpenCommand;
      openDirectoryCommand =
        if openDirectoryCommand != null then
          openDirectoryCommand
        else
          (path: [
            finalName
            "${directoryFlag}${path}"
          ]);
      openRunCommand =
        if openRunCommand != null then
          openRunCommand
        else
          (cmd: [
            finalName
            execFlag
            cmd
          ]);
      openRunPrefix =
        if openRunPrefix != null then
          openRunPrefix
        else
          [
            finalName
            execFlag
          ];
      openShellCommand =
        if openShellCommand != null then
          openShellCommand
        else
          (cmd: [
            finalName
            execFlag
            "sh"
            "-c"
            cmd
          ]);
      openWithClass =
        if openWithClass != null then
          openWithClass
        else
          (class: [
            finalName
            "${classFlag}${class}"
          ]);
      openRunWithClass =
        if openRunWithClass != null then
          openRunWithClass
        else
          (class: cmd: [
            finalName
            "${classFlag}${class}"
            execFlag
            cmd
          ]);
    };

  mkKdeProgram =
    {
      name,
      package ? null,
      openCommand ? null,
      openFileCommand ? null,
      additionalPackages ? [ ],
      desktopFile ? null,
      dirsToPersist ? [ ],
      filesToPersist ? [ ],
    }:
    let
      nameParts = lib.splitString "." name;
      resolvedPackage = if package != null then package else lib.getAttrFromPath nameParts kde;
      resolvedDesktopFile =
        if desktopFile != null then desktopFile else "org.kde.${lib.last nameParts}.desktop";
    in
    mkProgram {
      inherit
        name
        openCommand
        openFileCommand
        additionalPackages
        dirsToPersist
        filesToPersist
        ;
      package = resolvedPackage;
      desktopFile = resolvedDesktopFile;
    };

  mkKdeTerminal =
    {
      name,
      package ? null,
      openCommand ? null,
      openDirectoryCommand ? null,
      openRunCommand ? null,
      openRunPrefix ? null,
      openShellCommand ? null,
      openWithClass ? null,
      openRunWithClass ? null,
      additionalPackages ? [ ],
      desktopFile ? null,
      dirsToPersist ? [ ],
      filesToPersist ? [ ],
      execFlag ? "-e",
      directoryFlag ? "--workdir ",
      classFlag ? "--class ",
    }:
    let
      nameParts = lib.splitString "." name;
      resolvedPackage = if package != null then package else lib.getAttrFromPath nameParts kde;
      resolvedDesktopFile =
        if desktopFile != null then desktopFile else "org.kde.${lib.last nameParts}.desktop";
    in
    mkTerminal {
      inherit
        name
        openCommand
        openDirectoryCommand
        openRunCommand
        openRunPrefix
        openShellCommand
        openWithClass
        openRunWithClass
        additionalPackages
        dirsToPersist
        filesToPersist
        execFlag
        directoryFlag
        classFlag
        ;
      package = resolvedPackage;
      desktopFile = resolvedDesktopFile;
    };

  mkGnomeProgram =
    {
      name,
      package ? null,
      openCommand ? null,
      openFileCommand ? null,
      additionalPackages ? [ ],
      desktopFile ? null,
      dirsToPersist ? [ ],
      filesToPersist ? [ ],
    }:
    let
      nameParts = lib.splitString "." name;
      resolvedPackage = if package != null then package else lib.getAttrFromPath nameParts gnome;
      resolvedDesktopFile =
        if desktopFile != null then desktopFile else "org.gnome.${lib.last nameParts}.desktop";
    in
    mkProgram {
      inherit
        name
        openCommand
        openFileCommand
        additionalPackages
        dirsToPersist
        filesToPersist
        ;
      package = resolvedPackage;
      desktopFile = resolvedDesktopFile;
    };

  mkGnomeTerminal =
    {
      name,
      package ? null,
      openCommand ? null,
      openDirectoryCommand ? null,
      openRunCommand ? null,
      openRunPrefix ? null,
      openShellCommand ? null,
      openWithClass ? null,
      openRunWithClass ? null,
      additionalPackages ? [ ],
      desktopFile ? null,
      dirsToPersist ? [ ],
      filesToPersist ? [ ],
      execFlag ? "--",
      directoryFlag ? "--working-directory=",
      classFlag ? "--class=",
    }:
    let
      nameParts = lib.splitString "." name;
      resolvedPackage = if package != null then package else lib.getAttrFromPath nameParts gnome;
      resolvedDesktopFile =
        if desktopFile != null then desktopFile else "org.gnome.${lib.last nameParts}.desktop";
    in
    mkTerminal {
      inherit
        name
        openCommand
        openDirectoryCommand
        openRunCommand
        openRunPrefix
        openShellCommand
        openWithClass
        openRunWithClass
        additionalPackages
        dirsToPersist
        filesToPersist
        execFlag
        directoryFlag
        classFlag
        ;
      package = resolvedPackage;
      desktopFile = resolvedDesktopFile;
    };

  kdePrograms = {
    wallet = mkKdeProgram {
      name = "kwallet";
      additionalPackages = [
        kde.kwalletmanager
        pkgs.kwalletcli
      ];
      dirsToPersist = [ ".local/share/kwalletd" ];
      filesToPersist = [ ".config/kwalletrc" ];
    };
    fileBrowser = mkKdeProgram {
      name = "pcmanfm";
      package = pkgs.pcmanfm;
      desktopFile = "pcmanfm.desktop";
      dirsToPersist = [
        ".config/libfm"
        ".config/pcmanfm"
      ];
    };
    archiver = mkKdeProgram {
      name = "ark";
      dirsToPersist = [ ".local/share/ark" ];
      filesToPersist = [ ".config/arkrc" ];
    };
    textEditor = mkKdeProgram {
      name = "kate";
      dirsToPersist = [
        ".config/kate"
        ".local/share/kate"
      ];
      filesToPersist = [
        ".config/katerc"
        ".config/kate-externaltoolspluginrc"
        ".config/katevirc"
      ];
    };
    advancedTextEditor = mkKdeProgram {
      name = "ghostwriter";
      dirsToPersist = [
        ".cache/ghostwriter"
        ".local/share/ghostwriter"
      ];
    };
    terminal = mkKdeTerminal {
      name = "konsole";
      filesToPersist = [ ".config/konsolerc" ];
    };
    additionalTerminal = mkKdeTerminal {
      name = "konsole";
      filesToPersist = [ ".config/konsolerc" ];
    };
    systemSettings = mkKdeProgram {
      name = "systemsettings";
      dirsToPersist = [ ".cache/systemsettings" ];
      filesToPersist = [ ".config/systemsettingsrc" ];
    };
    networkSettings = mkKdeProgram { name = "plasma-nm"; };
    imageViewer = mkKdeProgram {
      name = "gwenview";
      filesToPersist = [ ".config/gwenviewrc" ];
    };
    imageEditor = mkKdeProgram {
      name = "spectacle";
      filesToPersist = [ ".config/spectaclerc" ];
    };
    paintImageEditor = mkKdeProgram {
      name = "kolourpaint";
      filesToPersist = [ ".config/kolourpaintrc" ];
    };
    pdfViewer = mkKdeProgram {
      name = "okular";
      dirsToPersist = [ ".local/share/okular" ];
      filesToPersist = [ ".config/okularrc" ];
    };
    videoPlayer = mkKdeProgram { name = "dragon"; };
    musicPlayer = mkKdeProgram {
      name = "elisa";
      dirsToPersist = [
        ".cache/elisa"
        ".local/share/elisa"
      ];
      filesToPersist = [ ".config/elisarc" ];
    };
    emailClient = mkKdeProgram { name = "kmail"; };
    calendar = mkKdeProgram { name = "korganizer"; };
    contacts = mkKdeProgram {
      name = "kaddressbook";
      dirsToPersist = [
        ".config/akonadi"
        ".local/share/akonadi"
      ];
      filesToPersist = [
        ".config/akonadi_contactrc"
        ".config/kaddressbookrc"
      ];
    };
    taskManager = mkKdeProgram { name = "plasma-systemmonitor"; };
    diskUsage = mkKdeProgram { name = "filelight"; };
    calculator = mkKdeProgram { name = "kcalc"; };
    clock = mkKdeProgram {
      name = "kclock";
      dirsToPersist = [ ".cache/kclock" ];
      filesToPersist = [ ".config/kclockrc" ];
    };
    webBrowser = mkKdeProgram { name = "falkon"; };
    dialog = mkKdeProgram { name = "kdialog"; };
    gitGui = mkProgram {
      name = "gitg";
      package = pkgs.gitg;
      desktopFile = "gitg.desktop";
    };
    gamesMine = mkKdeProgram { name = "kmines"; };
    gamesCards = mkKdeProgram { name = "kpat"; };
    sudoku = mkKdeProgram { name = "ksudoku"; };
  };

  gnomePrograms = {
    wallet = mkGnomeProgram {
      name = "gnome-keyring";
      dirsToPersist = [ ".local/share/keyrings" ];
    };
    fileBrowser = mkGnomeProgram { name = "nautilus"; };
    archiver = mkGnomeProgram { name = "file-roller"; };
    textEditor = mkGnomeProgram { name = "gedit"; };
    advancedTextEditor = mkGnomeProgram { name = "gnome-text-editor"; };
    terminal = mkGnomeTerminal { name = "gnome-terminal"; };
    additionalTerminal = mkGnomeTerminal { name = "gnome-terminal"; };
    systemSettings = mkGnomeProgram { name = "gnome-control-center"; };
    networkSettings = mkGnomeProgram { name = "gnome-control-center"; };
    imageViewer = mkGnomeProgram { name = "eog"; };
    imageEditor = mkGnomeProgram { name = "gnome-screenshot"; };
    paintImageEditor = mkGnomeProgram { name = "drawing"; };
    pdfViewer = mkGnomeProgram { name = "evince"; };
    videoPlayer = mkGnomeProgram { name = "totem"; };
    musicPlayer = mkGnomeProgram { name = "gnome-music"; };
    emailClient = mkGnomeProgram { name = "geary"; };
    calendar = mkGnomeProgram { name = "gnome-calendar"; };
    contacts = mkGnomeProgram { name = "gnome-contacts"; };
    taskManager = mkGnomeProgram { name = "gnome-system-monitor"; };
    diskUsage = mkGnomeProgram { name = "baobab"; };
    calculator = mkGnomeProgram { name = "gnome-calculator"; };
    clock = mkGnomeProgram { name = "gnome-clocks"; };
    webBrowser = mkGnomeProgram { name = "epiphany"; };
    dialog = mkGnomeProgram { name = "zenity"; };
    gitGui = mkProgram {
      name = "gitg";
      package = pkgs.gitg;
      desktopFile = "gitg.desktop";
    };
    gamesMine = mkGnomeProgram { name = "gnome-mines"; };
    gamesCards = mkGnomeProgram { name = "aisleriot"; };
    sudoku = mkGnomeProgram { name = "gnome-sudoku"; };
  };

  sharedPrograms = {
    officeSuite = mkProgram {
      name = "onlyoffice";
      package = pkgs.onlyoffice-desktopeditors;
      desktopFile = "onlyoffice-desktopeditors.desktop";
      dirsToPersist = [
        ".config/onlyoffice"
        ".local/share/onlyoffice"
      ];
    };
    drawingProgram = mkProgram {
      name = "gimp";
      package = pkgs.gimp;
      desktopFile = "gimp.desktop";
      dirsToPersist = [
        ".cache/gimp"
        ".config/GIMP"
      ];
    };
  };

  desktopPreference = self.user.settings.desktopPreference or "gnome";
  isKDE = desktopPreference == "kde";
  isGnome = desktopPreference == "gnome";

  selectedPrograms =
    (
      if isKDE then
        kdePrograms
      else if isGnome then
        gnomePrograms
      else
        gnomePrograms
    )
    // sharedPrograms;
in
{
  name = "programs";

  group = "desktop-modules";
  input = "linux";

  assertions = [
    {
      assertion = (self.user.isStandalone or false) || (self.isModuleEnabled "desktop-modules.programs");
      message = "Home desktop-modules.programs requires system desktop-modules.programs to be enabled (unless standalone)!";
    }
  ];

  settings = {
    additionalPackages = [
      pkgs.xdg-desktop-portal
      pkgs.libnotify
    ];
    additionalKDEPackages = [
      kde.qttools
      kde.xdg-desktop-portal-kde
      kde.kcmutils
    ];
    additionalGnomePackages = [
      gnome.xdg-desktop-portal-gnome
      gnome.xdg-desktop-portal-gtk
    ];
    additionalPrograms = [
      pkgs.easytag
      pkgs.popsicle
      pkgs.cheese
    ];
    additionalDirsToPersist = [
      ".cache/easytag"
      ".config/easytag"
    ];
    additionalFilesToPersist = [ ];
    additionalKDEDirsToPersist = [
      ".local/share/kactivitymanagerd"
      ".local/share/RecentDocuments"
      ".local/share/kscreen"
      ".cache/KDE"
      ".local/share/baloo"
      ".local/share/kwrite"
    ];
    additionalKDEFilesToPersist = [
      ".config/kglobalshortcutsrc"
      ".config/kwinrc"
      ".config/plasmarc"
      ".config/kcminputrc"
      ".config/kscreenlockerrc"
      ".config/kwriterc"
    ];
    additionalGnomeDirsToPersist = [ ];
    additionalGnomeFilesToPersist = [ ];
    installGames = false;
    installSystemSettings = false;
    installOfficeSuite = false;
    additionalIconThemes = [ ];
  };

  on = {
    linux.init =
      config:
      lib.mkIf self.isEnabled {
        nx.preferences.desktop.programs = {
          wallet = lib.mkDefault selectedPrograms.wallet;
          fileBrowser = lib.mkDefault selectedPrograms.fileBrowser;
          archiver = lib.mkDefault selectedPrograms.archiver;
          textEditor = lib.mkDefault selectedPrograms.textEditor;
          advancedTextEditor = lib.mkDefault selectedPrograms.advancedTextEditor;
          terminal = lib.mkDefault selectedPrograms.terminal;
          additionalTerminal = lib.mkDefault selectedPrograms.additionalTerminal;
          systemSettings = lib.mkDefault selectedPrograms.systemSettings;
          networkSettings = lib.mkDefault selectedPrograms.networkSettings;
          imageViewer = lib.mkDefault selectedPrograms.imageViewer;
          imageEditor = lib.mkDefault selectedPrograms.imageEditor;
          paintImageEditor = lib.mkDefault selectedPrograms.paintImageEditor;
          pdfViewer = lib.mkDefault selectedPrograms.pdfViewer;
          videoPlayer = lib.mkDefault selectedPrograms.videoPlayer;
          musicPlayer = lib.mkDefault selectedPrograms.musicPlayer;
          emailClient = lib.mkDefault selectedPrograms.emailClient;
          calendar = lib.mkDefault selectedPrograms.calendar;
          contacts = lib.mkDefault selectedPrograms.contacts;
          taskManager = lib.mkDefault selectedPrograms.taskManager;
          diskUsage = lib.mkDefault selectedPrograms.diskUsage;
          calculator = lib.mkDefault selectedPrograms.calculator;
          clock = lib.mkDefault selectedPrograms.clock;
          webBrowser = lib.mkDefault selectedPrograms.webBrowser;
          dialog = lib.mkDefault selectedPrograms.dialog;
          gitGui = lib.mkDefault selectedPrograms.gitGui;
          drawingProgram = lib.mkDefault selectedPrograms.drawingProgram;
        };
      };

    home =
      config:
      let
        prefs = config.nx.preferences.desktop.programs;
        isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

        iconThemeString = config.nx.preferences.theme.icons.primary;
        iconThemePackageName = lib.head (lib.splitString "/" iconThemeString);
        iconThemePackage = lib.getAttr iconThemePackageName pkgs;
        iconThemeName = lib.head (lib.tail (lib.splitString "/" iconThemeString));

        fallbackIconThemeString = config.nx.preferences.theme.icons.fallback;
        fallbackIconThemePackageName = lib.head (lib.splitString "/" fallbackIconThemeString);
        fallbackIconThemePackage = lib.getAttr fallbackIconThemePackageName pkgs;

        getProgramPackages =
          program:
          if program != null && program.package != null then
            [ program.package ] ++ (program.additionalPackages or [ ])
          else
            [ ];

        gamePackages =
          (getProgramPackages selectedPrograms.gamesMine)
          ++ (getProgramPackages selectedPrograms.gamesCards)
          ++ (getProgramPackages selectedPrograms.sudoku);

        officeSuitePackages = getProgramPackages selectedPrograms.officeSuite;
      in
      {
        home.packages =
          (getProgramPackages prefs.wallet)
          ++ (getProgramPackages prefs.dialog)
          ++ (getProgramPackages prefs.fileBrowser)
          ++ (getProgramPackages prefs.archiver)
          ++ (getProgramPackages prefs.textEditor)
          ++ (getProgramPackages prefs.advancedTextEditor)
          ++ (getProgramPackages prefs.terminal)
          ++ (getProgramPackages prefs.additionalTerminal)
          ++ (lib.optionals self.settings.installSystemSettings (getProgramPackages prefs.systemSettings))
          ++ (lib.optionals self.settings.installSystemSettings (getProgramPackages prefs.networkSettings))
          ++ (getProgramPackages prefs.imageViewer)
          ++ (getProgramPackages prefs.imageEditor)
          ++ (getProgramPackages prefs.paintImageEditor)
          ++ (getProgramPackages prefs.pdfViewer)
          ++ (getProgramPackages prefs.videoPlayer)
          ++ (getProgramPackages prefs.musicPlayer)
          ++ (getProgramPackages prefs.emailClient)
          ++ (getProgramPackages prefs.calendar)
          ++ (getProgramPackages prefs.contacts)
          ++ (getProgramPackages prefs.taskManager)
          ++ (getProgramPackages prefs.diskUsage)
          ++ (getProgramPackages prefs.calculator)
          ++ (getProgramPackages prefs.clock)
          ++ (getProgramPackages prefs.webBrowser)
          ++ (getProgramPackages prefs.gitGui)
          ++ (getProgramPackages prefs.drawingProgram)
          ++ (lib.optionals self.settings.installOfficeSuite officeSuitePackages)
          ++ (lib.optionals self.settings.installGames gamePackages)
          ++ self.settings.additionalPackages
          ++ self.settings.additionalPrograms
          ++ self.settings.additionalIconThemes
          ++ [
            iconThemePackage
            fallbackIconThemePackage
          ]
          ++ (if isKDE then self.settings.additionalKDEPackages else [ ])
          ++ (if isGnome then self.settings.additionalGnomePackages else [ ])
          ++ config.nx.preferences.desktop.additionalPrograms;

        gtk.iconTheme = lib.mkForce {
          name = iconThemeName;
          package = iconThemePackage;
        };

        services.gnome-keyring.enable = lib.mkForce isGnome;

        programs.niri = lib.mkIf isNiriEnabled {
          settings = {
            window-rules = [
              {
                matches = [
                  {
                    app-id = "org.kde.kwalletmanager";
                  }
                ];
                default-column-width = {
                  proportion = 0.5;
                };
              }
            ];
          };
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            "image/jpeg" = prefs.imageViewer.desktopFile;
            "image/jpg" = prefs.imageViewer.desktopFile;
            "image/png" = prefs.imageViewer.desktopFile;
            "image/gif" = prefs.imageViewer.desktopFile;
            "image/webp" = prefs.imageViewer.desktopFile;
            "image/bmp" = prefs.imageViewer.desktopFile;
            "image/tiff" = prefs.imageViewer.desktopFile;
            "image/svg+xml" = prefs.imageViewer.desktopFile;

            "application/pdf" = prefs.pdfViewer.desktopFile;

            "video/mp4" = prefs.videoPlayer.desktopFile;
            "video/avi" = prefs.videoPlayer.desktopFile;
            "video/mkv" = prefs.videoPlayer.desktopFile;
            "video/webm" = prefs.videoPlayer.desktopFile;
            "video/x-msvideo" = prefs.videoPlayer.desktopFile;
            "video/quicktime" = prefs.videoPlayer.desktopFile;

            "audio/mpeg" = prefs.musicPlayer.desktopFile;
            "audio/mp3" = prefs.musicPlayer.desktopFile;
            "audio/ogg" = prefs.musicPlayer.desktopFile;
            "audio/flac" = prefs.musicPlayer.desktopFile;
            "audio/wav" = prefs.musicPlayer.desktopFile;

            "application/zip" = prefs.archiver.desktopFile;
            "application/x-rar-compressed" = prefs.archiver.desktopFile;
            "application/x-tar" = prefs.archiver.desktopFile;
            "application/gzip" = prefs.archiver.desktopFile;
            "application/x-7z-compressed" = prefs.archiver.desktopFile;

            "text/plain" = prefs.textEditor.desktopFile;
            "text/markdown" = prefs.advancedTextEditor.desktopFile;
            "application/x-shellscript" = prefs.textEditor.desktopFile;

            "inode/directory" = prefs.fileBrowser.desktopFile;

            "text/html" = prefs.webBrowser.desktopFile;
            "application/xhtml+xml" = prefs.webBrowser.desktopFile;
            "x-scheme-handler/http" = prefs.webBrowser.desktopFile;
            "x-scheme-handler/https" = prefs.webBrowser.desktopFile;
            "x-scheme-handler/ftp" = prefs.webBrowser.desktopFile;
            "x-scheme-handler/chrome" = prefs.webBrowser.desktopFile;
            "application/x-extension-htm" = prefs.webBrowser.desktopFile;
            "application/x-extension-html" = prefs.webBrowser.desktopFile;
            "application/x-extension-shtml" = prefs.webBrowser.desktopFile;
            "application/x-extension-xhtml" = prefs.webBrowser.desktopFile;
            "application/x-extension-xht" = prefs.webBrowser.desktopFile;
          }
          // (
            if self.settings.installOfficeSuite then
              {
                "application/vnd.oasis.opendocument.text" = selectedPrograms.officeSuite.desktopFile;
                "application/vnd.oasis.opendocument.spreadsheet" = selectedPrograms.officeSuite.desktopFile;
                "application/vnd.oasis.opendocument.presentation" = selectedPrograms.officeSuite.desktopFile;
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document" =
                  selectedPrograms.officeSuite.desktopFile;
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" =
                  selectedPrograms.officeSuite.desktopFile;
                "application/vnd.openxmlformats-officedocument.presentationml.presentation" =
                  selectedPrograms.officeSuite.desktopFile;
                "application/msword" = selectedPrograms.officeSuite.desktopFile;
                "application/vnd.ms-excel" = selectedPrograms.officeSuite.desktopFile;
                "application/vnd.ms-powerpoint" = selectedPrograms.officeSuite.desktopFile;
              }
            else
              { }
          );
        };

        xdg.configFile = {
          "menus/applications.menu".text = ''
            <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
             "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
            <Menu>
              <Name>Applications</Name>
              <Directory>applications.directory</Directory>

              <AppDir>/etc/profiles/per-user/${config.home.username}/share/applications</AppDir>
              <AppDir>/run/current-system/sw/share/applications</AppDir>

              <Include>
                <All/>
              </Include>
            </Menu>
          '';
        }
        // lib.optionalAttrs isKDE {
          "kdeglobals".text = ''
            [General]
            TerminalApplication=${
              lib.concatStringsSep " " (
                helpers.runWithAbsolutePath config prefs.additionalTerminal prefs.additionalTerminal.openCommand [ ]
              )
            }
            TerminalService=${prefs.additionalTerminal.desktopFile}
          '';
        };

        xdg.portal = lib.mkIf (self.user.isStandalone or false) {
          enable = true;
          extraPortals = [
            pkgs.xdg-desktop-portal-gtk
            pkgs.xdg-desktop-portal-gnome
          ]
          ++ (lib.optionals isKDE [
            pkgs.kdePackages.xdg-desktop-portal-kde
          ]);
          config = {
            common = {
              default = if isKDE then [ "kde" ] else [ "gtk" ];
              "org.freedesktop.impl.portal.Secret" = if isKDE then [ "kde" ] else [ "gnome" ];
              "org.freedesktop.impl.portal.ScreenCast" = "gnome";
              "org.freedesktop.impl.portal.Location" = "gtk";
              "org.freedesktop.impl.portal.FileChooser" = "gtk";
            };
          };
        };

        home.persistence."${self.persist}" =
          let
            getProgramDirs = program: if program != null then (program.dirsToPersist or [ ]) else [ ];
            getProgramFiles = program: if program != null then (program.filesToPersist or [ ]) else [ ];

            allProgramDirs =
              (getProgramDirs prefs.wallet)
              ++ (getProgramDirs prefs.fileBrowser)
              ++ (getProgramDirs prefs.archiver)
              ++ (getProgramDirs prefs.textEditor)
              ++ (getProgramDirs prefs.advancedTextEditor)
              ++ (getProgramDirs prefs.terminal)
              ++ (getProgramDirs prefs.additionalTerminal)
              ++ (lib.optionals self.settings.installSystemSettings (getProgramDirs prefs.systemSettings))
              ++ (getProgramDirs prefs.imageViewer)
              ++ (getProgramDirs prefs.imageEditor)
              ++ (getProgramDirs prefs.paintImageEditor)
              ++ (getProgramDirs prefs.pdfViewer)
              ++ (getProgramDirs prefs.videoPlayer)
              ++ (getProgramDirs prefs.musicPlayer)
              ++ (getProgramDirs prefs.emailClient)
              ++ (getProgramDirs prefs.calendar)
              ++ (getProgramDirs prefs.contacts)
              ++ (getProgramDirs prefs.taskManager)
              ++ (getProgramDirs prefs.diskUsage)
              ++ (getProgramDirs prefs.calculator)
              ++ (getProgramDirs prefs.clock)
              ++ (getProgramDirs prefs.webBrowser)
              ++ (getProgramDirs prefs.gitGui)
              ++ (getProgramDirs prefs.drawingProgram)
              ++ (lib.optionals self.settings.installOfficeSuite (getProgramDirs selectedPrograms.officeSuite));

            allProgramFiles =
              (getProgramFiles prefs.wallet)
              ++ (getProgramFiles prefs.fileBrowser)
              ++ (getProgramFiles prefs.archiver)
              ++ (getProgramFiles prefs.textEditor)
              ++ (getProgramFiles prefs.advancedTextEditor)
              ++ (getProgramFiles prefs.terminal)
              ++ (getProgramFiles prefs.additionalTerminal)
              ++ (lib.optionals self.settings.installSystemSettings (getProgramFiles prefs.systemSettings))
              ++ (getProgramFiles prefs.imageViewer)
              ++ (getProgramFiles prefs.imageEditor)
              ++ (getProgramFiles prefs.paintImageEditor)
              ++ (getProgramFiles prefs.pdfViewer)
              ++ (getProgramFiles prefs.videoPlayer)
              ++ (getProgramFiles prefs.musicPlayer)
              ++ (getProgramFiles prefs.emailClient)
              ++ (getProgramFiles prefs.calendar)
              ++ (getProgramFiles prefs.contacts)
              ++ (getProgramFiles prefs.taskManager)
              ++ (getProgramFiles prefs.diskUsage)
              ++ (getProgramFiles prefs.calculator)
              ++ (getProgramFiles prefs.clock)
              ++ (getProgramFiles prefs.webBrowser)
              ++ (getProgramFiles prefs.gitGui)
              ++ (getProgramFiles prefs.drawingProgram)
              ++ (lib.optionals self.settings.installOfficeSuite (getProgramFiles selectedPrograms.officeSuite));
          in
          {
            directories = [
              ".config/dconf"
              ".local/share/applications"
              ".config/libaccounts-glib"
              ".config/htop"
              ".config/btop"
              ".config/pulse"
            ]
            ++ allProgramDirs
            ++ self.settings.additionalDirsToPersist
            ++ (if isKDE then self.settings.additionalKDEDirsToPersist else [ ])
            ++ (if isGnome then self.settings.additionalGnomeDirsToPersist else [ ]);

            files = [
              ".local/share/user-places.xbel"
            ]
            ++ allProgramFiles
            ++ self.settings.additionalFilesToPersist
            ++ (if isKDE then self.settings.additionalKDEFilesToPersist else [ ])
            ++ (if isGnome then self.settings.additionalGnomeFilesToPersist else [ ]);
          };
      };

    linux.system = config: {
      services.gnome.gnome-keyring.enable = lib.mkForce isGnome;

      programs.dconf.enable = true;

      xdg.portal = {
        enable = true;
        extraPortals =
          with pkgs;
          [
            xdg-desktop-portal-gtk
            xdg-desktop-portal-gnome
          ]
          ++ lib.optionals isKDE [
            kdePackages.xdg-desktop-portal-kde
          ];
        config = {
          common = {
            default = if isKDE then [ "kde" ] else [ "gtk" ];
            "org.freedesktop.impl.portal.Secret" = if isKDE then [ "kwallet" ] else [ "gnome-keyring" ];
            "org.freedesktop.impl.portal.ScreenCast" = "gnome";
            "org.freedesktop.impl.portal.Location" = "gtk";
            "org.freedesktop.impl.portal.FileChooser" = "gtk";
          };
        };
      };
    };
  };
}
