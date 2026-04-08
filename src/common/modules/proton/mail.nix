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
  name = "mail";

  group = "proton";
  input = "common";

  settings = {
    forceX11 = true;
    isolateConfig = true;
    package = pkgs-unstable.protonmail-desktop;
  };

  requiredArchitectures = [ "x86_64" ];

  on = {
    linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = lib.mkIf (self.linux.isModuleEnabled "desktop.niri") [
        "proton-mail"
      ];
    };

    enabled = config: {
      nx.preferences.desktop.programs.emailClient = {
        name = lib.mkForce "proton-mail";
        package = lib.mkForce null;
        localBin = lib.mkForce true;
        openCommand = lib.mkForce [ "proton-mail" ];
        openFileCommand = lib.mkForce (path: [
          "proton-mail"
          path
        ]);
        desktopFile = lib.mkForce "proton-mail.desktop";
      };
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
              paths = [ self.settings.package ];
              buildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram $out/bin/proton-mail ${wrapperArgs}

                rm -f $out/share/applications/proton-mail.desktop
                mkdir -p $out/share/applications
                substitute ${self.settings.package}/share/applications/proton-mail.desktop \
                  $out/share/applications/proton-mail.desktop \
                  --replace-fail "Exec=proton-mail" "Exec=$out/bin/proton-mail"
              '';
            })
          else
            self.settings.package;
        isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      in
      {
        home.file.".local/bin/proton-mail" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            exec ${protonmailWrapped}/bin/proton-mail "$@"
          '';
        };

        programs.niri = lib.mkIf isNiriEnabled {
          settings = {
            binds = lib.mkIf (!(self.isModuleEnabled "mail-stack.neomutt")) (
              with config.lib.niri.actions;
              {
                "Mod+Ctrl+Alt+O" = {
                  action = spawn-sh "niri-scratchpad --app-id \"Proton Mail\" --all-windows --spawn proton-mail";
                  hotkey-overlay.title = "Apps:Mails";
                };
              }
            );

            window-rules = [
              {
                matches = [ { app-id = "Proton Mail"; } ];
                block-out-from = "screencast";
              }
            ]
            ++ lib.optionals (!(self.isModuleEnabled "mail-stack.neomutt")) [
              {
                matches = [ { app-id = "Proton Mail"; } ];
                min-width = 1500;
                min-height = 800;
                open-on-workspace = "scratch";
                open-floating = true;
                open-focused = false;
              }
              {
                matches = [
                  {
                    app-id = "Proton Mail";
                    title = ".*(Reminder|Calendar|Event|Task|Address Book|Preferences|Options|Settings).*";
                  }
                ];
                open-on-workspace = "nonexistent";
                open-focused = true;
              }
            ];
          };
        };

        home.persistence."${self.persist}" = lib.mkIf self.settings.isolateConfig {
          directories = [ ".config/proton-mail" ];
        };
      };
  };
}
