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
  name = "swaylock";

  group = "desktop-modules";
  input = "linux";

  settings = {
    useFancy = false;
    useEffects = false;
    daemonize = true;
    showFailedAttempts = true;
    showKeyboardLayout = true;
  };

  module = {
    linux.home = config: {
      programs.swaylock = lib.mkIf (!self.settings.useFancy && !self.settings.useEffects) {
        enable = true;
        package = pkgs.swaylock;
        settings = {
          daemonize = self.settings.daemonize;
          show-failed-attempts = self.settings.showFailedAttempts;
          show-keyboard-layout = self.settings.showKeyboardLayout;
          image = lib.mkDefault null;
        };
      };

      home.packages =
        if self.settings.useFancy then
          (with pkgs; [
            swaylock-fancy
          ])
        else if self.settings.useEffects then
          (with pkgs; [
            swaylock-effects
          ])
        else
          [ ];
    };

    when = {
      modules.linux.security.yubikey = {
        enable = true;
        enableU2fAuth = true;
      };
      do.linux.system = config: {
        security.pam.services.swaylock.u2fAuth = true;
        security.pam.services.swaylock.rules.auth.u2f.order =
          config.security.pam.services.swaylock.rules.auth.unix.order + 10;
      };
    };
  };
}
