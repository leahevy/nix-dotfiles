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
  name = "swaylock";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  defaults = {
    useFancy = false;
    useEffects = false;
    daemonize = true;
    showFailedAttempts = true;
    showKeyboardLayout = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
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
}
