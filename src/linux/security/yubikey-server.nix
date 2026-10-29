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
  name = "yubikey-server";

  group = "security";
  input = "linux";

  disableOnVirtual = true;

  assertions = [
    {
      assertion = !self.isModuleEnabled "linux.security.yubikey";
      message = "yubikey-server and yubikey modules are mutually exclusive!";
    }
  ];

  module = {
    linux.system =
      config:
      let
        luksNames = helpers.getDiskoLuksDeviceNames (config.disko.devices or { });
        hasLuks = luksNames != [ ];

        enrollScript = pkgs.writeShellScriptBin "nx-yubikey-server-enroll" ''
          set -euo pipefail

          cryptsetup=${pkgs.cryptsetup}/bin/cryptsetup
          cryptenroll=${pkgs.systemd}/bin/systemd-cryptenroll

          if [ "$(${pkgs.coreutils}/bin/id -u)" -ne 0 ]; then
            echo "This script must be run as root!" >&2
            exit 1
          fi

          device="''${1:-}"
          if [ -z "$device" ]; then
            echo "Usage: nx-yubikey-server-enroll <luks-device>" >&2
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

          "$cryptenroll" "$device" \
            --fido2-device=auto \
            --fido2-with-client-pin=no \
            --fido2-with-user-presence=no

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
        boot.initrd.luks.devices = lib.genAttrs luksNames (_: {
          crypttabExtraOpts = [ "fido2-device=auto" ];
        });

        boot.initrd.systemd.settings.Manager.DefaultDeviceTimeoutSec = lib.mkIf hasLuks (
          lib.mkDefault "infinity"
        );

        environment.systemPackages = [ enrollScript ];
      };
  };
}
