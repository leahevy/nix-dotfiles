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
  host = self.host;
  ifSet = helpers.ifSet;
in
{
  name = "sound";

  configuration =
    context@{ config, options, ... }:
    {
      services.pulseaudio.enable = ifSet host.settings.system.sound.pulse.enabled false;
      security.rtkit.enable = ifSet host.settings.system.sound.pulse.enabled false;
      services.pipewire = {
        enable =
          (ifSet host.settings.system.sound.pulse.enabled false)
          || (ifSet host.settings.system.desktop.gnome.enabled false);
        alsa.enable = ifSet host.settings.system.sound.pulse.enabled false;
        alsa.support32Bit = ifSet host.settings.system.sound.pulse.enabled false;
        pulse.enable = ifSet host.settings.system.sound.pulse.enabled false;
      };
    };
}
