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
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    let
      systemConfig = self.host.getModuleConfig "sound.pipewire";
      defaultSink = systemConfig.defaultSink or null;

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
}
