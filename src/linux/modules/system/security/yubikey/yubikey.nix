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
  name = "yubikey";

  group = "security";
  input = "linux";
  namespace = "system";

  settings = {
    modelId = null;
    lockSessionOnUnplug = false;
    enableU2fAuth = false;
    useU2fAuthForSudo = true;
    useU2fAuthForLogin = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      services.pcscd.enable = true;

      services.udev.packages = [ pkgs.yubikey-personalization ];

      environment.systemPackages = with pkgs; [
        yubikey-personalization
        yubikey-manager
        libfido2
        pam_u2f
        pamtester
      ];

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
        sopsFile = self.config.secretsPath "yubikey-u2f-keys";
        mode = "0644";
      };

      security.pam.u2f.settings.authfile =
        lib.mkIf self.settings.enableU2fAuth config.sops.secrets.yubikey-u2f-keys.path;

      security.pam.services = lib.mkIf self.settings.enableU2fAuth {
        sudo.u2fAuth = self.settings.useU2fAuthForSudo;
        login.u2fAuth = self.settings.useU2fAuthForLogin;
      };
    };
}
