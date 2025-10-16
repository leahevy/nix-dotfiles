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
  name = "pipewire";

  group = "sound";
  input = "linux";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      services.pulseaudio.enable = lib.mkForce false;

      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        jack.enable = true;
        pulse.enable = true;
      };
    };
}
