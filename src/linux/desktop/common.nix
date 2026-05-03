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
  name = "common";

  group = "desktop";
  input = "linux";

  options = {
    graphicalSessionServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Service names to wire into graphical-session.target (PartOf + After).";
    };
  };

  submodules = {
    linux = {
      desktop-modules = {
        keyd = true;
        gamemode = true;
      };
      power = {
        modes = true;
      };
      sound = {
        pipewire = true;
      };
      graphics = {
        opengl = true;
      };
      services = {
        dbus = true;
      };
    };
  };

  module = {
    home =
      { config, graphicalSessionServices, ... }:
      {
        systemd.user.services = lib.listToAttrs (
          map (
            name:
            lib.nameValuePair name {
              Unit = {
                PartOf = [ "graphical-session.target" ];
                After = [ "graphical-session.target" ];
              };
            }
          ) graphicalSessionServices
        );
      };

    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          string = "Theme directory .* of theme .* has no size field";
          user = true;
        }
        {
          string = "gtk_widget_";
          user = true;
        }
        {
          string = "gtk.*: assertion .* failed";
          user = true;
        }
        {
          string = "gdk_gl_context_make_current\\(\\) failed";
          user = true;
        }
        {
          string = "gdk_gl_context_.*assertion .* failed";
          user = true;
        }
        {
          string = "g_object_ref: assertion .* failed";
          user = true;
        }
        {
          string = "animated_list_item_get_destroying: assertion .* failed";
          user = true;
        }
        {
          string = "g_dbus_proxy_get_object_path: assertion .* failed";
          user = true;
        }
        {
          string = "GFileInfo created without standard::.*";
          user = true;
        }
        {
          string = "file ../gio/gfileinfo\\.c:.*should not be reached";
          user = true;
        }
        {
          string = "gtk_.* must be called before gtk_init.*";
          user = true;
        }
        {
          string = "No IM module matching GTK_IM_MODULE=.*found";
          user = true;
        }
        {
          string = "GTK can't handle compose tables this large";
          user = true;
        }
        {
          string = "The new GL renderer has been renamed to gl\\. Try GSK_RENDERER=help";
          user = true;
        }
        {
          tag = "systemd";
          string = "Failed to enqueue SYSTEMD_USER_WANTS job, ignoring: Transaction for (sound|smartcard)\\.target/start is destructive";
          user = true;
          unitless = true;
        }
        {
          string = "Source ID [0-9]+ was not found when attempting to remove it";
          user = true;
        }
        {
          string = "QDBusConnection: name .* had owner";
          user = true;
        }
        {
          string = "QDBusConnection: couldn't handle call to CreateMonitor";
          user = true;
        }
        {
          string = "QThreadStorage: entry .* destroyed before end of thread";
          user = true;
        }
        {
          string = "QPainter::.*";
          user = true;
        }
        {
          string = "QObject::disconnect: wildcard call disconnects from destroyed signal";
          user = true;
        }
        {
          string = "qrc:/.*\\.qml:[0-9]+:[0-9]+: QML.*";
          user = true;
        }
        {
          string = "QQmlApplicationEngine failed to load component";
          user = true;
        }
        {
          string = "virtual.*QDBusError.*The name is not activatable";
          user = true;
        }
        {
          string = "qt\\.sql\\.sqlite: Unsupported option.*";
          user = true;
        }
        {
          string = "qt\\.gui\\.imageio\\.jpeg: Not a JPEG file: starts with";
          user = true;
        }
        {
          string = "qt\\.multimedia\\.symbolsresolver: Couldn't.*pipewire";
          user = true;
        }
        {
          string = "Connecting to deprecated signal QDBusConnectionInterface::.*";
          user = true;
        }
        {
          string = "endResetModel called on .* without calling beginResetModel first";
          user = true;
        }
        {
          string = "Type .* unavailable";
          user = true;
        }
        {
          string = ".*: module \"kvantum\" is not installed";
          user = true;
        }
        {
          string = ".*: Unresolved raw mime type.*";
          user = true;
        }
        {
          string = "kf\\.kio\\.gui: Cannot read information about filesystem";
          user = true;
        }
        {
          string = "kf\\.kio\\.gui: couldn't create thumbnail dir";
          user = true;
        }
        {
          string = "kf\\.kio\\.core\\.connection: Socket not connected";
          user = true;
        }
        {
          string = "kf\\.kio\\.core: An error occurred during write";
          user = true;
        }
        {
          string = "kf\\.config\\.core: couldn't lock global file";
          user = true;
        }
        {
          string = "kf\\.coreaddons:.*";
          user = true;
        }
        {
          string = "kf\\.kio\\.widgets:.*";
          user = true;
        }
        {
          string = "kf\\.windowsystem:.*may only be used on X11";
          user = true;
        }
        {
          string = "kf\\.kirigami\\.layouts:.*";
          user = true;
        }
        {
          string = "org\\.kde\\.kdegraphics.*: .*alignment=.*";
          user = true;
        }
        {
          string = "org\\.kde\\.pim\\..*";
          user = true;
        }
        {
          string = "Could not load default global viewproperties";
          user = true;
        }
        {
          string = "Unknown class .* in session saved data";
          user = true;
        }
        {
          string = "Could not find plugin kf6/parts/konsolepart";
          user = true;
        }
        {
          string = "Trying to enable pgp signatures, but pgp not enabled in this build";
          user = true;
        }
        {
          string = "Fatal error while loading the sidebar view qml component";
          user = true;
        }
        {
          string = "On Wayland, .* requires KDE Plasma's KWin compositor.*";
          user = true;
        }
        {
          string = "Remember requesting the interface on your desktop file: X-KDE-Wayland-Interfaces=.*";
          user = true;
        }
        {
          string = "Couldn't start kglobalaccel from org\\.kde\\.kglobalaccel\\.service.*";
          user = true;
        }
        {
          string = "Failed to lock file.*hm_kdeglobals\\.lock";
          user = true;
        }
        {
          string = "couldn't lock global file";
          user = true;
        }
        {
          string = "No event config could be found for event id .* under notifyrc file";
          user = true;
        }
        {
          string = "unhandled exception.*in Json::Value::find.*requires objectValue or nullValue";
          user = true;
        }
        {
          string = "libKExiv2: Cannot load metadata from file.*Error.*unknown image type";
          user = true;
        }
        {
          string = "dbus-.*org\\.kde\\.secretservicecompat.*Failed with result";
          user = true;
        }
        {
          string = "dbus-.*org\\.kde\\.kwalletd6.*Failed with result";
          user = true;
        }
        {
          string = "Client public key size is invalid";
          user = true;
        }
        {
          string = "Could not connect to Secret Service";
          user = true;
        }
        {
          string = "mpris_player.vala:[0-9]+: MPRIS .*album art error";
          user = true;
        }
        {
          string = "Could not find any platform plugin";
          user = true;
        }
        {
          string = "Loading IM context type .* failed";
          user = true;
        }
        {
          string = "Failed to open X11 display";
          user = true;
        }
        {
          string = "No X display connection, ignoring X11 parent";
          user = true;
        }
        {
          string = "Unhandled parent window type";
          user = true;
        }
        {
          string = "Autoready failed:.*Unit wayland-wm@.*\\.service not loaded";
          user = true;
        }
        {
          string = "pressure-vessel-wrap\\[[0-9]+\\]: [WD]:.*";
          user = true;
        }
        {
          string = ".*: Error executing command as another user: Not authorized.*gamemode.*";
          user = true;
        }
        {
          string = "application: invalid escaped exec argument character:.*";
          user = true;
        }
        {
          string = "Unable to replace properties on [0-9]+: Error getting properties for ID";
          user = true;
        }
        {
          string = "Children but no menu.*children-display.*property";
          user = true;
        }
        {
          string = ".*: Unable to connect to [0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+:[0-9]+: Host is down";
          all = true;
        }
      ];
    };

    linux.home = config: {
      home = {
        sessionVariables = {
          QT_QPA_PLATFORMTHEME = lib.mkForce "gtk3";
          QT_QPA_PLATFORMTHEME_QT6 = lib.mkForce "gtk3";
        };
      };
    };

    linux.system = config: {
      services.libinput.enable =
        if self.isVirtual then false else helpers.ifSet self.host.settings.system.touchpad.enabled false;

      console.keyMap = self.host.settings.system.keymap.console;

      environment.systemPackages = with pkgs; [
        gvfs
        gcr
      ];

      security.polkit.enable = true;

      xdg.portal = {
        enable = true;
      };
    };
  };
}
