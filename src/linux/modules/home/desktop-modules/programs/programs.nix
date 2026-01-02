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
  desktopPreference = self.desktop.primary.name;
  isKDE = desktopPreference == "kde";
  isGnome = desktopPreference == "gnome";
  unknown = throw "Desktop preference ${desktopPreference} is not available!";
in
{
  name = "programs";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  assertions = [
    {
      assertion =
        (self.user.isStandalone or false)
        || (self.host.isModuleEnabled or (x: false)) "desktop-modules.programs";
      message = "Home desktop-modules.programs requires system desktop-modules.programs to be enabled (unless standalone)!";
    }
  ];

  settings =
    let
      kde = pkgs.kdePackages;
      gnome = pkgs;
      define =
        {
          name,
          package ? null,
          openCommand ? null,
          openFileCommand ? null,
          additionalPackages ? [ ],
          desktopFile ? null,
        }:
        let
          nameParts = lib.splitString "." name;
          resolvePackage =
            if isKDE then
              lib.getAttrFromPath nameParts kde
            else if isGnome then
              lib.getAttrFromPath nameParts gnome
            else
              unknown;
          resolveDesktopFile =
            if desktopFile != null then
              desktopFile
            else if isKDE then
              "org.kde.${lib.last nameParts}.desktop"
            else if isGnome then
              "org.gnome.${lib.last nameParts}.desktop"
            else
              "${lib.last nameParts}.desktop";
        in
        {
          inherit name;
          package = if package != null then package else resolvePackage;
          openCommand = if openCommand != null then openCommand else (lib.last nameParts);
          openFileCommand =
            if openFileCommand != null then
              openFileCommand
            else
              (if openCommand != null then openCommand else (lib.last nameParts));
          additionalPackages = if additionalPackages != null then additionalPackages else [ ];
          desktopFile = resolveDesktopFile;
        };
      defineAll =
        kdeArgs: gnomeArgs:
        if isKDE then
          define kdeArgs
        else if isGnome then
          define gnomeArgs
        else
          unknown;
    in
    {
      wallet = defineAll {
        name = "kwallet";
        additionalPackages = [
          kde.kwalletmanager
          pkgs.kwalletcli
        ];
      } { name = "gnome-keyring"; };
      fileBrowser = defineAll { name = "dolphin"; } { name = "nautilus"; };
      archiver = defineAll { name = "ark"; } { name = "file-roller"; };
      textEditor = defineAll { name = "kate"; } { name = "gedit"; };
      advancedTextEditor = defineAll { name = "ghostwriter"; } { name = "gnome-text-editor"; };
      terminal = defineAll { name = "konsole"; } { name = "gnome-terminal"; };
      systemSettings = defineAll { name = "systemsettings"; } { name = "gnome-control-center"; };
      networkSettings = defineAll { name = "plasma-nm"; } { name = "gnome-control-center"; };
      imageViewer = defineAll { name = "gwenview"; } { name = "eog"; };
      imageEditor = defineAll { name = "spectacle"; } { name = "gnome-screenshot"; };
      paintImageEditor = defineAll { name = "kolourpaint"; } { name = "drawing"; };
      pdfViewer = defineAll { name = "okular"; } { name = "evince"; };
      videoPlayer = defineAll { name = "dragon"; } { name = "totem"; };
      musicPlayer = defineAll { name = "elisa"; } { name = "gnome-music"; };
      emailClient = defineAll { name = "kmail"; } { name = "geary"; };
      calendar = defineAll { name = "korganizer"; } { name = "gnome-calendar"; };
      contacts = defineAll { name = "kaddressbook"; } { name = "gnome-contacts"; };
      taskManager = defineAll { name = "plasma-systemmonitor"; } { name = "gnome-system-monitor"; };
      diskUsage = defineAll { name = "filelight"; } { name = "baobab"; };
      calculator = defineAll { name = "kcalc"; } { name = "gnome-calculator"; };
      clock = defineAll { name = "kclock"; } { name = "gnome-clocks"; };
      webBrowser = defineAll { name = "falkon"; } { name = "epiphany"; };
      gamesMine = defineAll { name = "kmines"; } { name = "gnome-mines"; };
      gamesCards = defineAll { name = "kpat"; } { name = "aisleriot"; };
      sudoku = defineAll { name = "ksudoku"; } { name = "gnome-sudoku"; };
      dialog = defineAll { name = "kdialog"; } { name = "zenity"; };
      gitGui = defineAll {
        name = "dolphin-plugins";
        openCommand = "dolphin";
        openFileCommand = "dolphin";
      } { name = "gitg"; };
      officeSuite = define {
        name = "onlyoffice";
        package = pkgs.onlyoffice-desktopeditors;
        desktopFile = "onlyoffice-desktopeditors.desktop";
      };
      drawingProgram = define {
        name = "gimp";
        package = pkgs.gimp;
        desktopFile = "gimp.desktop";
      };
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
      installGames = false;
      installSystemSettings = false;
      installOfficeSuite = false;
      additionalIconThemes = [ ];
    };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      getDesktopFileContainingPath = program: "${program.package}/share/applications";
      getDesktopFilePath = program: "${getDesktopFileContainingPath program}/${program.desktopFile}";

      iconThemeString = self.theme.icons.primary;
      iconThemePackageName = lib.head (lib.splitString "/" iconThemeString);
      iconThemePackage = lib.getAttr iconThemePackageName pkgs;
      iconThemeName = lib.head (lib.tail (lib.splitString "/" iconThemeString));

      fallbackIconThemeString = self.theme.icons.fallback;
      fallbackIconThemePackageName = lib.head (lib.splitString "/" fallbackIconThemeString);
      fallbackIconThemePackage = lib.getAttr fallbackIconThemePackageName pkgs;
    in
    {
      home.packages =
        let
          conditionallyAdd =
            path:
            let
              resolved = self.settings.${path};
              resolvedPackage =
                if resolved != null && resolved.package != null then [ resolved.package ] else [ ];
              additionalPackages =
                if resolved != null && resolved.additionalPackages != null then
                  resolved.additionalPackages
                else
                  [ ];
            in
            resolvedPackage ++ additionalPackages;
        in
        (conditionallyAdd "wallet")
        ++ (conditionallyAdd "dialog")
        ++ (conditionallyAdd "fileBrowser")
        ++ (conditionallyAdd "archiver")
        ++ (conditionallyAdd "textEditor")
        ++ (conditionallyAdd "advancedTextEditor")
        ++ (conditionallyAdd "terminal")
        ++ (if self.settings.installSystemSettings then conditionallyAdd "systemSettings" else [ ])
        ++ (if self.settings.installSystemSettings then conditionallyAdd "networkSettings" else [ ])
        ++ (conditionallyAdd "imageViewer")
        ++ (conditionallyAdd "imageEditor")
        ++ (conditionallyAdd "paintImageEditor")
        ++ (conditionallyAdd "pdfViewer")
        ++ (conditionallyAdd "videoPlayer")
        ++ (conditionallyAdd "musicPlayer")
        ++ (conditionallyAdd "emailClient")
        ++ (conditionallyAdd "calendar")
        ++ (conditionallyAdd "contacts")
        ++ (conditionallyAdd "taskManager")
        ++ (conditionallyAdd "diskUsage")
        ++ (conditionallyAdd "calculator")
        ++ (conditionallyAdd "clock")
        ++ (conditionallyAdd "webBrowser")
        ++ (conditionallyAdd "gitGui")
        ++ (conditionallyAdd "drawingProgram")
        ++ (lib.optionals self.settings.installOfficeSuite (conditionallyAdd "officeSuite"))
        ++ (
          if self.settings.installGames then
            ((conditionallyAdd "gamesMine") ++ (conditionallyAdd "gamesCards") ++ (conditionallyAdd "sudoku"))
          else
            [ ]
        )
        ++ self.settings.additionalPackages
        ++ self.settings.additionalPrograms
        ++ self.settings.additionalIconThemes
        ++ [
          iconThemePackage
          fallbackIconThemePackage
        ]
        ++ (if isKDE then self.settings.additionalKDEPackages else [ ])
        ++ (if isGnome then self.settings.additionalGnomePackages else [ ]);

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
          "image/jpeg" = self.settings.imageViewer.desktopFile;
          "image/jpg" = self.settings.imageViewer.desktopFile;
          "image/png" = self.settings.imageViewer.desktopFile;
          "image/gif" = self.settings.imageViewer.desktopFile;
          "image/webp" = self.settings.imageViewer.desktopFile;
          "image/bmp" = self.settings.imageViewer.desktopFile;
          "image/tiff" = self.settings.imageViewer.desktopFile;
          "image/svg+xml" = self.settings.imageViewer.desktopFile;

          "application/pdf" = self.settings.pdfViewer.desktopFile;

          "video/mp4" = self.settings.videoPlayer.desktopFile;
          "video/avi" = self.settings.videoPlayer.desktopFile;
          "video/mkv" = self.settings.videoPlayer.desktopFile;
          "video/webm" = self.settings.videoPlayer.desktopFile;
          "video/x-msvideo" = self.settings.videoPlayer.desktopFile;
          "video/quicktime" = self.settings.videoPlayer.desktopFile;

          "audio/mpeg" = self.settings.musicPlayer.desktopFile;
          "audio/mp3" = self.settings.musicPlayer.desktopFile;
          "audio/ogg" = self.settings.musicPlayer.desktopFile;
          "audio/flac" = self.settings.musicPlayer.desktopFile;
          "audio/wav" = self.settings.musicPlayer.desktopFile;

          "application/zip" = self.settings.archiver.desktopFile;
          "application/x-rar-compressed" = self.settings.archiver.desktopFile;
          "application/x-tar" = self.settings.archiver.desktopFile;
          "application/gzip" = self.settings.archiver.desktopFile;
          "application/x-7z-compressed" = self.settings.archiver.desktopFile;

          "text/plain" = self.settings.textEditor.desktopFile;
          "text/markdown" = self.settings.advancedTextEditor.desktopFile;
          "application/x-shellscript" = self.settings.textEditor.desktopFile;

          "inode/directory" = self.settings.fileBrowser.desktopFile;

          "text/html" = self.settings.webBrowser.desktopFile;
          "application/xhtml+xml" = self.settings.webBrowser.desktopFile;
          "x-scheme-handler/http" = self.settings.webBrowser.desktopFile;
          "x-scheme-handler/https" = self.settings.webBrowser.desktopFile;
          "x-scheme-handler/ftp" = self.settings.webBrowser.desktopFile;
          "x-scheme-handler/chrome" = self.settings.webBrowser.desktopFile;
          "application/x-extension-htm" = self.settings.webBrowser.desktopFile;
          "application/x-extension-html" = self.settings.webBrowser.desktopFile;
          "application/x-extension-shtml" = self.settings.webBrowser.desktopFile;
          "application/x-extension-xhtml" = self.settings.webBrowser.desktopFile;
          "application/x-extension-xht" = self.settings.webBrowser.desktopFile;
        }
        // (
          if self.settings.installOfficeSuite then
            {
              "application/vnd.oasis.opendocument.text" = self.settings.officeSuite.desktopFile;
              "application/vnd.oasis.opendocument.spreadsheet" = self.settings.officeSuite.desktopFile;
              "application/vnd.oasis.opendocument.presentation" = self.settings.officeSuite.desktopFile;
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document" =
                self.settings.officeSuite.desktopFile;
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" =
                self.settings.officeSuite.desktopFile;
              "application/vnd.openxmlformats-officedocument.presentationml.presentation" =
                self.settings.officeSuite.desktopFile;
              "application/msword" = self.settings.officeSuite.desktopFile;
              "application/vnd.ms-excel" = self.settings.officeSuite.desktopFile;
              "application/vnd.ms-powerpoint" = self.settings.officeSuite.desktopFile;
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
          TerminalApplication=${self.settings.terminal.openCommand}
          TerminalService=${self.settings.terminal.desktopFile}
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
          };
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/dconf"
          ".local/share/applications"
          ".cache/easytag"
          ".config/easytag"
          ".config/libaccounts-glib"
          ".cache/gimp"
          ".config/GIMP"
          ".config/htop"
          ".config/btop"
          ".cache/ghostwriter"
          ".local/share/ghostwriter"
          ".config/pulse"
        ]
        ++ lib.optionals (self.settings.officeSuite.name == "libreoffice") [
          ".config/libreoffice"
        ]
        ++ lib.optionals (self.settings.officeSuite.name == "onlyoffice") [
          ".config/onlyoffice"
          ".local/share/onlyoffice"
        ]
        ++ (
          if isGnome then
            [
              ".local/share/keyrings"
            ]
          else if isKDE then
            [
              ".local/share/kwalletd"
              ".local/share/kactivitymanagerd"
              ".local/share/RecentDocuments"
              ".local/share/kscreen"
              ".cache/kclock"
              ".cache/elisa"
              ".cache/KDE"
              ".cache/systemsettings"
              ".config/kate"
              ".config/akonadi"
              ".local/share/dolphin"
              ".local/share/baloo"
              ".local/share/okular"
              ".local/share/ark"
              ".local/share/elisa"
              ".local/share/kate"
              ".local/share/akonadi"
              ".local/share/kwrite"
            ]
          else
            [ ]
        );

        files = [
          ".local/share/user-places.xbel"
        ]
        ++ lib.optionals isKDE [
          ".config/kglobalshortcutsrc"
          ".config/kwinrc"
          ".config/plasmarc"
          ".config/systemsettingsrc"
          ".config/kcminputrc"
          ".config/kscreenlockerrc"
          ".config/dolphinrc"
          ".config/katerc"
          ".config/konsolerc"
          ".config/okularrc"
          ".config/gwenviewrc"
          ".config/spectaclerc"
          ".config/kwalletrc"
          ".config/arkrc"
          ".config/kclockrc"
          ".config/elisarc"
          ".config/kate-externaltoolspluginrc"
          ".config/katevirc"
          ".config/kolourpaintrc"
          ".config/akonadi_contactrc"
          ".config/kaddressbookrc"
          ".config/kwriterc"
        ];
      };
    };
}
