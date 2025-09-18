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
  name = "pipewire";

  configuration =
    context@{ config, options, ... }:
    {
      services.pulseaudio.enable = false;

      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
    };
}
