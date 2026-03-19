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

  settings = {
    defaultSink = null;
  };

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

        extraConfig.pipewire-pulse = lib.mkIf (self.settings.defaultSink != null) {
          "99-default-sink" = {
            "context.exec" = [
              {
                path = "${pkgs.pulseaudio}/bin/pactl";
                args = "set-default-sink ${self.settings.defaultSink}";
              }
            ];
          };
        };
      };
    };
}
