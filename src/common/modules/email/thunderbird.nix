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
  name = "thunderbird";

  group = "email";
  input = "common";

  on = {
    init =
      config:
      lib.mkIf self.isEnabled {
        nx.preferences.desktop.programs.emailClient = {
          name = "thunderbird";
          package = pkgs.thunderbird;
          openCommand = "thunderbird";
          openFileCommand = "thunderbird";
          desktopFile = "thunderbird.desktop";
        };

        nx.preferences.desktop.programs.calendar = {
          name = "thunderbird";
          package = null;
          openCommand = "thunderbird";
          openFileCommand = "thunderbird";
          desktopFile = "thunderbird.desktop";
        };
      };

    home =
      config:
      let
        isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      in
      {
        home.packages = with pkgs; [
          thunderbird
        ];

        home.persistence."${self.persist}" = {
          directories = [
            ".thunderbird"
            ".cache/thunderbird"
            ".config/.mozilla/thunderbird"
          ];
        };

        programs.niri = lib.mkIf isNiriEnabled {
          settings = {
            binds =
              lib.mkIf (!(self.isModuleEnabled "mail-stack.neomutt") && !(self.isModuleEnabled "proton.mail"))
                (
                  with config.lib.niri.actions;
                  {
                    "Mod+Ctrl+Alt+O" = {
                      action = spawn-sh "niri-scratchpad --app-id thunderbird --all-windows --spawn thunderbird";
                      hotkey-overlay.title = "Apps:Mails";
                    };
                  }
                );

            window-rules = [
              {
                matches = [ { app-id = "thunderbird"; } ];
                block-out-from = "screencast";
              }
            ]
            ++
              lib.optionals
                (!(self.isModuleEnabled "mail-stack.neomutt") && !(self.isModuleEnabled "proton.mail"))
                [
                  {
                    matches = [ { app-id = "thunderbird"; } ];
                    min-width = 1500;
                    min-height = 800;
                    open-on-workspace = "scratch";
                    open-floating = true;
                    open-focused = false;
                  }
                  {
                    matches = [
                      {
                        app-id = "thunderbird";
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
