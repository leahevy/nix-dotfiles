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
  name = "mail";

  group = "proton";
  input = "common";

  settings = {
    forceX11 = true;
    makeMailDefault = true;
    makeCalendarDefault = true;
    makeContactsDefault = true;
  };

  submodules = lib.optionalAttrs self.isLinux {
    linux = {
      software = {
        flatpak = true;
      };
    };
  };

  requirePlatforms = [ "linux" ];
  requireArchitectures = [ "x86_64" ];

  module = {
    linux.enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          tag = "systemd-coredump";
          string = "Process [0-9]+ \\(Proton Mail Bet\\) of user [0-9]+ dumped core\\.";
        }
      ];

      nx.linux.desktop.niri.autostartPrograms = lib.mkIf (self.linux.isModuleEnabled "desktop.niri") [
        "proton-mail"
      ];
      nx.linux.desktop.niri.lateWindowRules =
        lib.mkIf (self.linux.isModuleEnabled "desktop.niri" && !(self.isModuleEnabled "mail-stack.neomutt"))
          [
            {
              match = {
                app-id = "me.proton.Mail";
              };
              skipStaticRule = true;
              apply = {
                float = true;
                workspace = "scratch";
                width = "1500";
                height = "800";
              };
            }
          ];
    };

    enabled =
      config:
      let
        mkEntry = flag: value: if flag then lib.mkForce value else lib.mkDefault value;
        protonProg = flag: {
          name = mkEntry flag "proton-mail";
          package = mkEntry flag null;
          localBin = mkEntry flag true;
          openCommand = mkEntry flag [ "proton-mail" ];
          openFileCommand = mkEntry flag (path: [
            "proton-mail"
            path
          ]);
          desktopFile = mkEntry flag "me.proton.Mail.desktop";
        };
      in
      {
        nx.preferences.desktop.programs.emailClient = protonProg self.settings.makeMailDefault;
        nx.preferences.desktop.programs.calendar = protonProg self.settings.makeCalendarDefault;
        nx.preferences.desktop.programs.contacts = protonProg self.settings.makeContactsDefault;
      };

    linux.home = config: {
      services.flatpak.packages = [ "me.proton.Mail" ];

      services.flatpak.overrides."me.proton.Mail".Environment = {
        ELECTRON_OZONE_PLATFORM_HINT = if self.settings.forceX11 then "x11" else "auto";
      };

      home.file."${defs.binDir}/proton-mail" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exec ${pkgs.flatpak}/bin/flatpak run me.proton.Mail "$@"
        '';
      };
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = lib.mkIf (!(self.isModuleEnabled "mail-stack.neomutt")) (
            with config.lib.niri.actions;
            {
              "Mod+Ctrl+Alt+O" = {
                action = spawn-sh "niri-scratchpad --app-id \"me.proton.Mail\" --all-windows --spawn proton-mail";
                hotkey-overlay.title = "Apps:Mails";
              };
            }
          );

          window-rules = [
            {
              matches = [ { app-id = "me.proton.Mail"; } ];
              block-out-from = "screencast";
            }
          ]
          ++ lib.optionals (!(self.isModuleEnabled "mail-stack.neomutt")) [
            {
              matches = [
                {
                  app-id = "me.proton.Mail";
                  title = ".*(Reminder|Calendar|Event|Task|Address Book|Preferences|Options|Settings).*";
                }
              ];
              open-on-workspace = "nonexistent";
              open-focused = true;
            }
          ];
        };
      };
    };
  };
}
