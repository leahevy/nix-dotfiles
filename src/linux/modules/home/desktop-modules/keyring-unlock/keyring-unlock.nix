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
  name = "keyring-unlock";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  defaults = {
    passwordSopsFile = "wallet.pass";
  };

  assertions = [
    {
      assertion = self.settings.passwordSopsFile != "";
      message = "Setting: passwordSopsFile required (sops file should be in profile input secrets)";
    }
  ];

  configuration =
    context@{ config, ... }:
    let
      isKDE = self.user.settings.desktopPreference == "kde";
      isGnome = self.user.settings.desktopPreference == "gnome";
    in
    {
      sops.secrets.${self.settings.passwordSopsFile} = {
        sopsFile = self.profile.secretsPath self.settings.passwordSopsFile;
        format = "binary";
        mode = "0400";
      };

      systemd.user.services.nx-keyring-unlock = {
        Unit = {
          Description = "Unlock desktop keyring automatically";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart =
            let
              passwordFile = config.sops.secrets.${self.settings.passwordSopsFile}.path;

              hashScript = pkgs.writeText "kwallet-hash.py" ''
                #!/usr/bin/env python3
                import sys
                import hashlib
                import base64

                def generate_kwallet_hash(password_file, salt_file):
                    try:
                        with open(password_file, 'r') as f:
                            password = f.read().strip().encode('utf-8')

                        with open(salt_file, 'rb') as f:
                            salt = f.read()

                        key = hashlib.pbkdf2_hmac('sha512', password, salt, 50000, 56)

                        return ','.join(f'0x{b:02x}' for b in key)

                    except Exception as e:
                        print(f"Error generating hash: {e}", file=sys.stderr)
                        sys.exit(1)

                if __name__ == "__main__":
                    if len(sys.argv) != 3:
                        print("Usage: kwallet-hash.py <password_file> <salt_file>", file=sys.stderr)
                        sys.exit(1)

                    password_file = sys.argv[1]
                    salt_file = sys.argv[2]
                    hash_result = generate_kwallet_hash(password_file, salt_file)
                    print(hash_result)
              '';

              unlockScript = pkgs.writeShellScriptBin "unlock-keyring" ''
                #!${pkgs.bash}/bin/bash
                export PATH="${
                  lib.makeBinPath [
                    pkgs.python3
                    pkgs.kdePackages.qttools
                    pkgs.dbus
                    pkgs.gnome-keyring
                    pkgs.systemd
                    pkgs.coreutils
                  ]
                }:$PATH"
                set -euo pipefail

                timeout=30
                while ! systemctl --user is-active dbus.service >/dev/null 2>&1 && [ $timeout -gt 0 ]; do
                  sleep 1
                  timeout=$((timeout - 1))
                done

                if [ $timeout -eq 0 ]; then
                  echo "D-Bus session not ready, exiting"
                  exit 1
                fi

                ${
                  if isKDE then
                    ''
                      timeout=30
                      while ! ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.kwalletd6 >/dev/null 2>&1 && [ $timeout -gt 0 ]; do
                        sleep 1
                        timeout=$((timeout - 1))
                      done

                      if [ $timeout -eq 0 ]; then
                        echo "KWallet daemon not available, exiting"
                        exit 1
                      fi

                      SALT_FILE="$HOME/.local/share/kwalletd/kdewallet.salt"
                      if [ ! -f "$SALT_FILE" ]; then
                        echo "Salt file not found: $SALT_FILE"
                        exit 1
                      fi

                      PASSWORD_HASH=$(python3 ${hashScript} "${passwordFile}" "$SALT_FILE")
                      echo "Unlocking KWallet with pamOpen..."
                      dbus-send --session --type=method_call --dest=org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.pamOpen string:kdewallet array:byte:$PASSWORD_HASH int32:0

                      echo "Opening KWallet for applications..."
                      HANDLE=$(${pkgs.kdePackages.qttools}/bin/qdbus org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.open kdewallet 0 "nx-keyring-unlock")
                      echo "KWallet handle: $HANDLE"

                    ''
                  else if isGnome then
                    ''
                      timeout=30
                      while ! ${pkgs.dbus}/bin/dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1 && [ $timeout -gt 0 ]; do
                        sleep 1
                        timeout=$((timeout - 1))
                      done

                      if [ $timeout -eq 0 ]; then
                        echo "D-Bus session services not ready, exiting"
                        exit 1
                      fi

                      echo "Unlocking GNOME Keyring..."
                      cat "${passwordFile}" | tr -d '\n\r' | ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --replace --unlock
                    ''
                  else
                    ''
                      echo "No keyring to unlock for this desktop environment"
                      exit 0
                    ''
                }
              '';
            in
            "${unlockScript}/bin/unlock-keyring";
          RemainAfterExit = true;
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
}
