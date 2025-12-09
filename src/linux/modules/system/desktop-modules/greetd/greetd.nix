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
  namespace = "system";

  settings = {
    package = null;
    cmdline = null;
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

  configuration =
    context@{ config, options, ... }:
    let
      isGnome = self.user.settings.desktopPreference == "gnome";
      isKDE = self.user.settings.desktopPreference == "kde";
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
        settings = rec {
          initial_session = {
            command = "${pkgs.uwsm}/bin/uwsm start ${self.settings.package}/bin/${self.settings.cmdline}";
            user = self.host.mainUser.username;
          };
          default_session = initial_session;
        };
      };

      systemd.services.greetd = lib.mkIf (isGnome || isKDE) {
        serviceConfig = {
          KeyringMode = lib.mkForce "inherit";
        };
      };

      services.xserver.displayManager.gdm.enable = lib.mkForce false;
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
}
