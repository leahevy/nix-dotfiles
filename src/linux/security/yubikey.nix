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
  name = "yubikey";

  group = "security";
  input = "linux";

  disableOnVirtual = true;

  settings = {
    modelId = null;
    lockSessionOnUnplug = false;
    enableU2fAuth = false;
    useU2fAuthForSudo = true;
    useU2fAuthForLogin = true;
    useU2fAuthForPolkit = true;
    enableU2fCue = true;
    enableYubikeyInitrdUnlock = true;
  };

  module = {
    enabled = config: {
      nx.linux.desktop-modules.keyd.deviceIdsToIgnore = [ "1050" ];
    };

    linux.system =
      config:
      let
        luksNames = lib.optionals self.settings.enableYubikeyInitrdUnlock (
          helpers.getDiskoLuksDeviceNames (config.disko.devices or { })
        );
        hasLuks = luksNames != [ ];

        enrollScript = pkgs.writeShellScriptBin "nx-yubikey-enroll" ''
          set -euo pipefail

          cryptsetup=${pkgs.cryptsetup}/bin/cryptsetup
          cryptenroll=${pkgs.systemd}/bin/systemd-cryptenroll

          if [ "$(${pkgs.coreutils}/bin/id -u)" -ne 0 ]; then
            echo "This script must be run as root!" >&2
            exit 1
          fi

          device="''${1:-}"
          if [ -z "$device" ]; then
            echo "Usage: nx-yubikey-enroll <luks-device>" >&2
            exit 1
          fi

          if ! "$cryptsetup" isLuks "$device"; then
            echo "$device is not a LUKS device!" >&2
            exit 1
          fi

          countTokens() {
            "$cryptsetup" luksDump "$1" | ${pkgs.gnugrep}/bin/grep -c "systemd-fido2" || true
          }

          tokensBefore=$(countTokens "$device")

          if [ "$tokensBefore" -gt 0 ]; then
            echo "Warning: $device already has $tokensBefore FIDO2 token(s) enrolled!"
            read -r -p "Enroll another one anyway? [y/N] " reply
            if [ "$reply" != "y" ] && [ "$reply" != "Y" ]; then
              echo "Aborted!" >&2
              exit 1
            fi
          fi

          read -r -p "Require a PIN in addition to the touch? [y/N] " withPin
          if [ "$withPin" = "y" ] || [ "$withPin" = "Y" ]; then
            pinFlag=yes
          else
            pinFlag=no
          fi

          "$cryptenroll" "$device" \
            --fido2-device=auto \
            --fido2-with-client-pin="$pinFlag" \
            --fido2-with-user-presence=yes

          tokensAfter=$(countTokens "$device")

          if [ "$tokensAfter" -gt "$tokensBefore" ]; then
            echo "Enrollment verified: systemd-fido2 tokens on $device went from $tokensBefore to $tokensAfter."
          else
            echo "Enrollment could not be verified on $device, token count stayed at $tokensAfter!" >&2
            exit 1
          fi
        '';
      in
      {
        services.pcscd.enable = true;
        hardware.gpgSmartcards.enable = true;

        boot.initrd.luks.devices = lib.genAttrs luksNames (_: {
          crypttabExtraOpts = [ "fido2-device=auto" ];
        });

        boot.initrd.systemd.settings.Manager.DefaultDeviceTimeoutSec = lib.mkIf hasLuks (
          lib.mkDefault "infinity"
        );

        services.udev.packages = [ pkgs.yubikey-personalization ];

        environment.systemPackages =
          (with pkgs; [
            yubikey-personalization
            yubikey-manager
            libfido2
            pam_u2f
            pamtester
          ])
          ++ lib.optional self.settings.enableYubikeyInitrdUnlock enrollScript;

        services.udev.extraRules = lib.mkIf self.settings.lockSessionOnUnplug ''
          ACTION=="remove",\
           SUBSYSTEM=="usb",\
           ENV{DEVTYPE}=="usb_device",\
           ENV{PRODUCT}=="${
             if self.settings.modelId != null then
               "1050/${lib.removePrefix "0" self.settings.modelId}/*"
             else
               "1050/*/*"
           }",\
           RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"
        '';

        sops.secrets.yubikey-u2f-keys = lib.mkIf self.settings.enableU2fAuth {
          format = "binary";
          sopsFile = self.profile.secretsPath "yubikey-u2f-keys";
          mode = "0644";
        };

        security.pam.u2f.settings.authfile =
          lib.mkIf self.settings.enableU2fAuth config.sops.secrets.yubikey-u2f-keys.path;

        security.pam.u2f.settings.cue = lib.mkIf self.settings.enableU2fAuth self.settings.enableU2fCue;

        systemd.services."polkit-agent-helper@".serviceConfig =
          lib.mkIf (self.settings.enableU2fAuth && self.settings.useU2fAuthForPolkit)
            {
              PrivateDevices = false;
              DeviceAllow = [
                "/dev/urandom r"
                "char-hidraw rw"
              ];
            };

        security.pam.services = lib.mkIf self.settings.enableU2fAuth {
          sudo.u2fAuth = self.settings.useU2fAuthForSudo;
          login.u2fAuth = self.settings.useU2fAuthForLogin;
          polkit-1.u2fAuth = self.settings.useU2fAuthForPolkit;
        };
      };
  };
}
