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

  module = {
    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          string = "spa\\.alsa:.*error pcm info.*No such device";
          user = true;
        }
        {
          string = "spa\\.alsa:.*error iterating devices.*No such device";
          user = true;
        }
        {
          string = "spa\\.alsa: Error opening low-level control device.*No such file or directory";
          user = true;
        }
        {
          string = "spa\\.alsa: can't open control for card.*No such file or directory";
          user = true;
        }
        {
          string = "spa\\.alsa:.*snd_pcm_start.*Broken pipe";
          user = true;
        }
        {
          string = "spa\\.alsa:.*snd_pcm_avail.*Broken pipe";
          user = true;
        }
        {
          string = "spa\\.alsa:.*snd_pcm_start.*File descriptor in bad state";
          user = true;
        }
        {
          string = "spa\\.alsa:.*snd_pcm_drop.*No such device";
          user = true;
        }
        {
          string = "spa\\.alsa:.*close failed.*No such device";
          user = true;
        }
        {
          string = "spa\\.alsa:.*playback open failed.*Device or resource busy";
          user = true;
        }
        {
          string = "spa\\.v4l2:.*VIDIOC_STREAMON: No space left on device";
          user = true;
        }
        {
          string = "spa\\.v4l2:.*Cannot open.*No such file or directory";
          user = true;
        }
        {
          string = "spa\\.bluez5\\.midi:.*RegisterApplication\\(\\) failed.*AlreadyExists";
          user = true;
        }
        {
          tag = "wireplumber";
          string = "spa\\.bluez5: BlueZ system service is not available";
          user = true;
          unitless = true;
        }
        {
          string = "pw\\.node:.*suspended -> error \\(Start error: Device or resource busy\\)";
          user = true;
        }
        {
          string = "pw\\.node:.*suspended -> error \\(Start error: No space left on device\\)";
          user = true;
        }
        {
          string = "pw\\.link:.*one of the nodes is in error";
          user = true;
        }
        {
          string = "pw\\.core: .* leaked proxy .* id:[0-9]+";
          user = true;
        }
        {
          string = "Caught PipeWire error: connection error";
          user = true;
        }
        {
          string = "wp-event-dispatcher: .*assertion.*already_registered_dispatcher.*failed";
          user = true;
        }
        {
          string = "Couldn't load pipewire.*library";
          user = true;
        }
        {
          string = "Couldn't resolve pipewire.*symbols";
          user = true;
        }
        {
          string = "kpipewire_vaapi_logging: VAAPI:.*";
          user = true;
        }
        {
          string = "The canary thread is apparently starving\\. Taking action\\.";
          user = true;
        }
        {
          string = "mod\\.protocol-pulse: client .* ERROR command:[0-9]+ \\(.*\\) tag:[0-9]+ error:[0-9]+ \\(.*\\)";
          user = true;
        }
        {
          string = "Realtime error: Could not get pidns for pid [0-9]+: Could not fstatat ns/pid: Not a directory";
          user = true;
        }
        {
          string = "Failed to get percentage from UPower";
          user = true;
        }
      ];
    };

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
