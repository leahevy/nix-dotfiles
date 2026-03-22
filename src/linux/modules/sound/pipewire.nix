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

  settings = {
    defaultSink = null;
  };

  on = {
    home =
      config:
      let
        defaultSink = self.settings.defaultSink;

        setDefaultSinkScript =
          sink:
          pkgs.writeShellScript "set-default-sink" ''
            SINK_NAME="${sink}"
            MAX_ATTEMPTS=45

            for i in $(${pkgs.coreutils}/bin/seq 1 $MAX_ATTEMPTS); do
              echo "Attempt $i/$MAX_ATTEMPTS: Checking for sink $SINK_NAME"

              if ! ${pkgs.pulseaudio}/bin/pactl info >/dev/null 2>&1; then
                echo "PipeWire/PulseAudio not ready yet, waiting..."
              else
                if ${pkgs.pulseaudio}/bin/pactl list sinks short | ${pkgs.gnugrep}/bin/grep -q "$SINK_NAME"; then
                  echo "Found sink $SINK_NAME, setting as default"
                  ${pkgs.pulseaudio}/bin/pactl set-default-sink "$SINK_NAME"
                  exit $?
                else
                  echo "PipeWire ready, but sink not found, waiting 1 second..."
                fi
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done

            echo "Sink $SINK_NAME not found after $MAX_ATTEMPTS attempts"
            exit 1
          '';
      in
      lib.mkIf (defaultSink != null) {
        systemd.user.services.set-default-sink = {
          Unit = {
            Description = "Set default audio sink";
            After = [
              "graphical-session.target"
              "pipewire-pulse.service"
            ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${setDefaultSinkScript defaultSink}";
            RemainAfterExit = true;
            SuccessExitStatus = [
              0
              1
            ];
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };

    linux.system = config: {
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
  };
}
