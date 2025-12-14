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

  group = "gpg";
  input = "common";
  namespace = "home";

  settings = {
    keyserver = "keys.openpgp.org";
  };

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
          maxCacheTtl = 10800;
          maxCacheTtlSsh = 10800;
          defaultCacheTtl = 10800;
          defaultCacheTtlSsh = 10800;
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

        scdaemonSettings = {
          disable-ccid = true;
        };

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

      home.file.".local/bin/gpg-upload-keys" = {
        text =
          let
            mainKey = if self.user.gpg != null then [ self.user.gpg ] else [ ];
            additionalKeys = self.user.additionalGPGKeys or [ ];
            allKeys = mainKey ++ additionalKeys;
            keyListString = lib.concatStringsSep " " allKeys;
          in
          ''
            #!/usr/bin/env bash
            set -euo pipefail

            KEYS=(${keyListString})
            KEYSERVER="${self.settings.keyserver}"

            if [ "''${#KEYS[@]}" -eq 0 ]; then
                echo "No GPG keys configured to upload"
                exit 0
            fi

            echo "Keyserver: $KEYSERVER"
            echo "Keys to upload:"
            for key in "''${KEYS[@]}"; do
                echo "  - $key"
            done
            echo ""
            read -p "Proceed with upload? [y/N]: " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Upload cancelled"
                exit 0
            fi

            echo "Uploading GPG keys to keyserver: $KEYSERVER"

            for key in "''${KEYS[@]}"; do
                echo "Uploading key: $key"
                if gpg --keyserver "$KEYSERVER" --send-keys "$key"; then
                    echo "✓ Successfully uploaded key: $key"
                else
                    echo "✗ Failed to upload key: $key" >&2
                fi
            done

            echo "Upload process completed"
          '';
        executable = true;
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".gnupg"
        ];
      };
    };
}
