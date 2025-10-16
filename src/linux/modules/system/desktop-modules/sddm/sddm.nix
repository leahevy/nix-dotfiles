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
  name = "sddm";

  group = "desktop-modules";
  input = "linux";
  namespace = "system";

  assertions = [
    {
      assertion = self.settings.cmdline != null && self.settings.cmdline != "";
      message = "Setting cmdline must be set, e.g. 'niri-session'";
    }
  ];

  defaults = {
    autologin = false;
  };

  configuration =
    context@{ config, options, ... }:
    let
      isGnome = self.user.settings.desktopPreference == "gnome";
      isKDE = self.user.settings.desktopPreference == "kde";
      uwsmSession = pkgs.runCommand "uwsm-session" { } ''
                mkdir -p $out/share/wayland-sessions
                cat > $out/share/wayland-sessions/uwsm-session.desktop << 'EOF'
        [Desktop Entry]
        Name=UWSM Session
        Comment=Start UWSM session with ${self.settings.cmdline}
        Exec=${pkgs.uwsm}/bin/uwsm start ${self.settings.package}/bin/${self.settings.cmdline}
        TryExec=${pkgs.uwsm}/bin/uwsm
        Type=Application
        DesktopNames=uwsm
        X-LightDM-DesktopName=UWSM Session
        X-GDM-SessionRegisters=true
        EOF
      '';
    in
    {
      boot.initrd.systemd.enable = lib.mkForce true;

      environment.systemPackages =
        (with pkgs; [
          uwsm
          libsecret
        ])
        ++ (
          if isGnome then
            (with pkgs; [
              gnome-keyring
            ])
          else if isKDE then
            (with pkgs; [
              kdePackages.kwallet
              kdePackages.kwallet-pam
            ])
          else
            [ ]
        );

      services.gnome.gnome-keyring.enable = lib.mkForce isGnome;
      programs.seahorse.enable = lib.mkForce isGnome;

      services.displayManager = {
        sessionPackages = [ uwsmSession ];
        sddm = {
          enable = true;
          wayland.enable = true;
          settings = lib.mkForce (
            {
              General = {
                DisplayServer = "wayland";
                DefaultSession = "uwsm-session.desktop";
                HaltCommand = "${pkgs.systemd}/bin/systemctl poweroff";
                RebootCommand = "${pkgs.systemd}/bin/systemctl reboot";
                InputMethod = "";
                Numlock = "off";
              };
              Wayland = {
                SessionDir = uwsmSession + "/share/wayland-sessions";
              };
            }
            // (
              if self.settings.autologin then
                {
                  Autologin = {
                    User = self.host.mainUser.username;
                    Session = "uwsm-session.desktop";
                    Relogin = true;
                  };
                }
              else
                { }
            )
          );
        };
      };

      systemd.services.display-manager = {
        serviceConfig = {
          KeyringMode = "inherit";
        };
      };

      services.greetd.enable = lib.mkForce false;
      services.xserver.displayManager.gdm.enable = lib.mkForce false;
      services.xserver.displayManager.lightdm.enable = lib.mkForce false;
      services.xserver.enable = lib.mkForce false;

      services.dbus.packages =
        if isGnome then
          (with pkgs; [
            gcr
            gnome-keyring
          ])
        else if isKDE then
          (with pkgs; [
            kdePackages.kwallet
          ])
        else
          [ ];

      security.pam.services.sddm-autologin = lib.mkForce {
        text = ''
          auth optional ${pkgs.systemd}/lib/security/pam_systemd_loadkey.so keyname=cryptsetup
          ${lib.optionalString isGnome "auth optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so"}
          ${lib.optionalString isKDE "auth optional ${pkgs.kdePackages.kwallet-pam}/lib/security/pam_kwallet5.so"}

          auth requisite pam_nologin.so
          auth required pam_succeed_if.so uid >= 1000 quiet
          auth required pam_permit.so

          account include login
          password include login
          session include login

          ${lib.optionalString isGnome "session optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start"}
          ${lib.optionalString isKDE "session optional ${pkgs.kdePackages.kwallet-pam}/lib/security/pam_kwallet5.so auto_start"}
        '';
      };

      security.pam.services.login = {
        enableGnomeKeyring = lib.mkForce isGnome;
        enableKwallet = lib.mkForce isKDE;
      };
    };
}
