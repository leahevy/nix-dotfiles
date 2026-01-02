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

  settings = {
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
      isKDE = self.desktop.primary.name == "kde";
      isGnome = self.desktop.primary.name == "gnome";
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

              kwalletUnlockScript = pkgs.writeText "kwallet-unlock.py" ''
                #!/usr/bin/env python3
                import sys
                import hashlib
                import dbus

                def generate_kwallet_hash(password_file, salt_file):
                    try:
                        with open(password_file, 'r') as f:
                            password = f.read().strip().encode('utf-8')

                        with open(salt_file, 'rb') as f:
                            salt = f.read()

                        key = hashlib.pbkdf2_hmac('sha512', password, salt, 50000, 56)
                        return key

                    except Exception as e:
                        print(f"Error generating hash: {e}", file=sys.stderr)
                        sys.exit(1)

                def unlock_kwallet(password_file, salt_file):
                    try:
                        hash_bytes = generate_kwallet_hash(password_file, salt_file)

                        bus = dbus.SessionBus()
                        proxy = bus.get_object('org.kde.kwalletd6', '/modules/kwalletd6')
                        hash_array = dbus.ByteArray(hash_bytes)

                        proxy.pamOpen('kdewallet', hash_array, 0, dbus_interface='org.kde.KWallet')

                        handle = proxy.open('kdewallet', 0, 'nx-keyring-unlock-test', dbus_interface='org.kde.KWallet')
                        is_open = handle > 0

                        if is_open:
                            print("KWallet unlock successful - wallet is open")
                            proxy.close(handle, False, 'nx-keyring-unlock-test', dbus_interface='org.kde.KWallet')
                            return True
                        else:
                            print("KWallet unlock failed - wallet is not open", file=sys.stderr)
                            return False

                    except Exception as e:
                        print(f"Error unlocking KWallet: {e}", file=sys.stderr)
                        return False

                if __name__ == "__main__":
                    if len(sys.argv) != 3:
                        print("Usage: kwallet-unlock.py <password_file> <salt_file>", file=sys.stderr)
                        sys.exit(1)

                    password_file = sys.argv[1]
                    salt_file = sys.argv[2]

                    if unlock_kwallet(password_file, salt_file):
                        sys.exit(0)
                    else:
                        sys.exit(1)
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
                export PYTHONPATH="${pkgs.python3Packages.dbus-python}/lib/python${pkgs.python3.pythonVersion}/site-packages:$PYTHONPATH"
                set -euo pipefail

                timeout=30
                while ! systemctl --user is-active dbus.service >/dev/null 2>&1 && [ $timeout -gt 0 ]; do
                  sleep 1
                  timeout=$((timeout - 1))
                done

                if [ $timeout -eq 0 ]; then
                  echo "D-Bus session not ready, skipping keyring unlock"
                  ${pkgs.util-linux}/bin/logger -p user.err -t nx-keyring-unlock "D-Bus session not ready - keyring unlock skipped"
                  exit 0
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
                        echo "KWallet daemon not available, skipping keyring unlock"
                        ${pkgs.util-linux}/bin/logger -p user.err -t nx-keyring-unlock "KWallet daemon not available - keyring unlock skipped"
                        exit 0
                      fi

                      SALT_FILE="$HOME/.local/share/kwalletd/kdewallet.salt"
                      if [ ! -f "$SALT_FILE" ]; then
                        echo "Salt file not found: $SALT_FILE, skipping keyring unlock"
                        ${pkgs.util-linux}/bin/logger -p user.err -t nx-keyring-unlock "KWallet salt file not found - keyring unlock skipped"
                        exit 0
                      fi

                      echo "Unlocking KWallet..."
                      python3 ${kwalletUnlockScript} "${passwordFile}" "$SALT_FILE"

                      if [ $? -eq 0 ]; then
                        echo "Opening KWallet for applications..."
                        HANDLE=$(${pkgs.kdePackages.qttools}/bin/qdbus org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.open kdewallet 0 "nx-keyring-unlock")
                        echo "KWallet handle: $HANDLE"
                      else
                        echo "KWallet unlock failed, continuing without keyring"
                        ${pkgs.util-linux}/bin/logger -p user.err -t nx-keyring-unlock "KWallet unlock failed - passwords will need to be entered manually"
                        exit 0
                      fi
                    ''
                  else if isGnome then
                    ''
                      timeout=30
                      while ! ${pkgs.dbus}/bin/dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1 && [ $timeout -gt 0 ]; do
                        sleep 1
                        timeout=$((timeout - 1))
                      done

                      if [ $timeout -eq 0 ]; then
                        echo "D-Bus session services not ready, skipping keyring unlock"
                        ${pkgs.util-linux}/bin/logger -p user.err -t nx-keyring-unlock "D-Bus session services not ready - GNOME keyring unlock skipped"
                        exit 0
                      fi

                      echo "Unlocking GNOME Keyring..."
                      cat "${passwordFile}" | tr -d '\n\r' | ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --replace --unlock

                      if [ $? -eq 0 ]; then
                        echo "GNOME Keyring unlock successful"
                      else
                        echo "GNOME Keyring unlock failed, continuing without keyring"
                        ${pkgs.util-linux}/bin/logger -p user.err -t nx-keyring-unlock "GNOME Keyring unlock failed - passwords will need to be entered manually"
                      fi
                      exit 0
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
