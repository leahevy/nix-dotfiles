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
  name = "greetd";

  group = "desktop-modules";
  input = "linux";

  settings = {
    package = null;
    cmdline = null;
    useAgreetyForDefaultSession = true;
  };

  assertions = [
    {
      assertion = self.settings.cmdline != null && self.settings.cmdline != "";
      message = "Setting cmdline must be set, e.g. 'niri-session'";
    }
    {
      assertion = self.settings.package != null && self.settings.package != "";
      message = "Setting package must be set, e.g. 'pkgs.niri'";
    }
  ];

  module = {
    system =
      config:
      let
        isGnome = self.user.settings.desktopPreference == "gnome";
        isKDE = self.user.settings.desktopPreference == "kde";
        sessionCommand = "${pkgs.systemd}/bin/systemd-cat -t uwsm_start ${pkgs.uwsm}/bin/uwsm start ${self.settings.package}/bin/${self.settings.cmdline}";
        initialSession = {
          command = sessionCommand;
          user = self.host.mainUser.username;
        };
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

        services.greetd = {
          enable = true;
          settings = {
            initial_session = initialSession;
            default_session =
              if self.settings.useAgreetyForDefaultSession then
                {
                  command = "${pkgs.greetd}/bin/agreety --cmd '${sessionCommand}' -f 6";
                  user = "greeter";
                }
              else
                initialSession;
          };
        };

        systemd.services.greetd = lib.mkMerge [
          {
            serviceConfig = {
              Restart = "always";
              RestartSec = "1s";
              RestartSteps = 5;
              RestartMaxDelaySec = "30s";
            };
            unitConfig = {
              StartLimitIntervalSec = 0;
            };
          }
          (lib.mkIf (isGnome || isKDE) {
            serviceConfig = {
              KeyringMode = lib.mkForce "inherit";
            };
          })
        ];

        services.displayManager.gdm.enable = lib.mkForce false;
        services.xserver.displayManager.lightdm.enable = lib.mkForce false;
        services.displayManager.sddm.enable = lib.mkForce false;
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

        security.pam.services.greetd = {
          enableKwallet = lib.mkForce isKDE;
          enableGnomeKeyring = lib.mkForce isGnome;
        };

        security.pam.services.login = {
          enableGnomeKeyring = lib.mkForce isGnome;
          enableKwallet = lib.mkForce isKDE;
        };
      };
  };
}
