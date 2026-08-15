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
  name = "signal-chat";

  group = "web-apps";
  input = "linux";

  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "Signal-Chat";
      description = "Display name of the desktop chat web-app";
    };
    webapp = lib.mkOption {
      type = lib.types.str;
      default = "signal-chat";
      description = "Web-app identifier used for the launcher and per-app profile paths";
    };
    categories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Network"
        "Utility"
      ];
      description = "Desktop entry categories for the web-app launcher";
    };
    protocol = lib.mkOption {
      type = lib.types.str;
      default = "https";
      description = "URL protocol used to reach the chat vhost";
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Subdomain under the homeserver domain serving the desktop chat channel";
    };
    args = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Extra path or query appended to the web-app URL";
    };
    windowSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 720;
      description = "Fixed pixel width and height of the floating chat window, kept square and centered";
    };
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if self ? user && self.user.isStandalone then
          self.user.homeserverDomain
        else if self ? host then
          self.host.homeserverDomain
        else
          null;
      description = "Domain serving the desktop chat channel";
    };
  };

  submodules = {
    linux = {
      desktop-modules = {
        web-app = true;
      };
    };
  };

  module = {
    ifEnabled.linux.desktop.niri.linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = [
        "signal-chat-webapp"
      ];
    };

    linux.home =
      {
        config,
        name,
        webapp,
        categories,
        protocol,
        subdomain,
        domain,
        ...
      }:
      let
        iconPath = "${helpers.packageFile args config.nx.linux.desktop-modules.web-app.dashboardIcons
          "svg/signal.svg"
        }";
        webAppSettings = {
          inherit
            name
            webapp
            categories
            protocol
            subdomain
            domain
            iconPath
            ;
          args = config.nx.linux.web-apps.signal-chat.args;
        };
      in
      {
        assertions = [
          {
            assertion = subdomain != null && subdomain != "";
            message = "signal-chat web-app subdomain required to be set!";
          }
          {
            assertion = domain != null && domain != "";
            message = "signal-chat web-app domain required to be set!";
          }
        ];

        home.file = (config.nx.linux.desktop-modules.web-app.buildWebApp webAppSettings).homeFiles;
        xdg.desktopEntries =
          (config.nx.linux.desktop-modules.web-app.buildWebApp webAppSettings).desktopEntries;
      };

    ifEnabled.linux.desktop.niri.home =
      {
        config,
        webapp,
        protocol,
        subdomain,
        domain,
        args,
        windowSize,
        ...
      }:
      lib.mkIf (config.nx.linux.desktop-modules.web-app.buildWebApp != null) (
        let
          appIds =
            (config.nx.linux.desktop-modules.web-app.buildWebApp {
              inherit
                webapp
                protocol
                subdomain
                domain
                args
                ;
            }).appIds;
          primaryAppId = builtins.head appIds;
        in
        {
          programs.niri = {
            settings = {
              binds = with config.lib.niri.actions; {
                "Mod+Ctrl+Alt+Backslash" = {
                  action = spawn-sh "niri-scratchpad --app-id ${primaryAppId} --all-windows --spawn signal-chat-webapp";
                  hotkey-overlay.title = "Apps:Signal-Chat";
                };
              };

              window-rules = map (appId: {
                matches = [ { app-id = appId; } ];
                default-column-width = {
                  fixed = windowSize;
                };
                default-window-height = {
                  fixed = windowSize;
                };
                open-on-workspace = "scratch";
                open-floating = true;
                open-focused = false;
                block-out-from = "screencast";
              }) appIds;
            };
          };
        }
      );
  };
}
