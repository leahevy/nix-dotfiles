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
  getPinentryPackage =
    if self.isDarwin then
      pkgs.pinentry_mac
    else if self.isLinux then
      let
        desktopPreference = self.user.settings.desktopPreference or "none";
      in
      if desktopPreference == "kde" then
        pkgs.pinentry-qt
      else if desktopPreference == "gnome" then
        pkgs.pinentry-gnome3
      else
        pkgs.pinentry-curses
    else
      pkgs.pinentry-curses;

  getPinentryProgram =
    if self.isDarwin then
      "pinentry-mac"
    else if self.isLinux then
      let
        desktopPreference = self.user.settings.desktopPreference or "none";
      in
      if desktopPreference == "kde" then
        "pinentry-qt"
      else if desktopPreference == "gnome" then
        "pinentry-gnome3"
      else
        "pinentry-curses"
    else
      "pinentry-curses";
in
{
  name = "gpg";

  configuration =
    context@{ config, options, ... }:
    {
      services = {
        gpg-agent = {
          enable = true;
          enableSshSupport = true;
          pinentry = {
            package = getPinentryPackage;
            program = getPinentryProgram;
          };
          maxCacheTtl = 86400;
          maxCacheTtlSsh = 86400;
          defaultCacheTtl = 43200;
          defaultCacheTtlSsh = 43200;
        };
      };

      home = {
        packages = [
          getPinentryPackage
          pkgs.gnupg
        ];
      };

      home.file.".gnupg/common.conf" = {
        source = self.symlinkFile config "common.conf";
      };

      programs.gpg = {
        enable = true;

        settings =
          { }
          // (
            if self.user.gpg != null then
              {
                default-key = self.user.gpg;
              }
            else
              { }
          );
      };

      home.file."${config.xdg.configHome}/fish-init/20-gpg-tty.fish".text = ''
        export GPG_TTY=$(tty)
      '';

      home.persistence."${self.persist}" = {
        directories = [
          ".gnupg"
        ];
      };
    };
}
