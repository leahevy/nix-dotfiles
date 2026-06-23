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
    isolateConfig = true;
    makeMailDefault = true;
    makeCalendarDefault = true;
    makeContactsDefault = true;
  };

  requirePlatforms = [ "linux" ];
  requireArchitectures = [ "x86_64" ];

  module = {
    ifEnabled.linux.desktop-modules.desktop-files.enabled = config: {
      nx.linux.desktop-modules.desktop-files.entries.proton-mail = {
        exec = "${self.binDir}/proton-mail %u";
        name = "Proton Mail";
        icon = "mail-archive-symbolic";
        categories = [
          "Network"
          "Email"
        ];
      };
    };

    linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = lib.mkIf (self.linux.isModuleEnabled "desktop.niri") [
        "proton-mail"
      ];
      nx.linux.desktop.niri.lateWindowRules =
        lib.mkIf (self.linux.isModuleEnabled "desktop.niri" && !(self.isModuleEnabled "mail-stack.neomutt"))
          [
            {
              match = {
                app-id = "proton-mail";
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
          desktopFile = mkEntry flag "proton-mail.desktop";
        };
      in
      {
        nx.preferences.desktop.programs.emailClient = protonProg self.settings.makeMailDefault;
        nx.preferences.desktop.programs.calendar = protonProg self.settings.makeCalendarDefault;
        nx.preferences.desktop.programs.contacts = protonProg self.settings.makeContactsDefault;
      };

    home =
      config:
      let
        needsWrapper = self.isLinux && (self.settings.forceX11 || self.settings.isolateConfig);
        wrapperArgs = lib.concatStringsSep " " (
          lib.optional self.settings.forceX11 "--set XDG_SESSION_TYPE x11"
          ++ lib.optional self.settings.isolateConfig ''--set XDG_CONFIG_HOME "${self.user.home}/.config/proton-mail"''
        );

        protonmailWrapped =
          if needsWrapper then
            (pkgs.symlinkJoin {
              name = "protonmail-desktop-wrapped";
              paths = [ pkgs.protonmail-desktop ];
              buildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram $out/bin/proton-mail ${wrapperArgs}

                rm -f $out/share/applications/proton-mail.desktop
                mkdir -p $out/share/applications
                substitute ${pkgs.protonmail-desktop}/share/applications/proton-mail.desktop \
                  $out/share/applications/proton-mail.desktop \
                  --replace-fail "Exec=proton-mail" "Exec=$out/bin/proton-mail"
              '';
            })
          else
            pkgs.protonmail-desktop;
      in
      {
        home.file."${defs.binDir}/proton-mail" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            exec ${protonmailWrapped}/bin/proton-mail "$@"
          '';
        };

        home.persistence."${self.persist}" = lib.mkIf self.settings.isolateConfig {
          directories = [ ".config/proton-mail" ];
        };
      };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = lib.mkIf (!(self.isModuleEnabled "mail-stack.neomutt")) (
            with config.lib.niri.actions;
            {
              "Mod+Ctrl+Alt+O" = {
                action = spawn-sh "niri-scratchpad --app-id \"proton-mail\" --all-windows --spawn proton-mail";
                hotkey-overlay.title = "Apps:Mails";
              };
            }
          );

          window-rules = [
            {
              matches = [ { app-id = "proton-mail"; } ];
              block-out-from = "screencast";
            }
          ]
          ++ lib.optionals (!(self.isModuleEnabled "mail-stack.neomutt")) [
            {
              matches = [
                {
                  app-id = "proton-mail";
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
