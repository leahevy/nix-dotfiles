args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  resolveDefaultSink =
    defaultSink: speakerSinkID: headsetSinkID:
    if defaultSink == "speaker" then
      (if speakerSinkID != null then speakerSinkID else headsetSinkID)
    else
      (if headsetSinkID != null then headsetSinkID else speakerSinkID);

  mkSinkMatchRules =
    sink: sinkRules:
    lib.optionals (sink != null) (
      (map (nodeName: {
        matchKey = "node.name";
        matchValue = nodeName;
        target = sink;
      }) sinkRules.nodeNames)
      ++ (map (binary: {
        matchKey = "application.process.binary";
        matchValue = binary;
        target = sink;
      }) sinkRules.binary)
    );

  luaEscape = s: lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s;

  luaRuleEntry =
    rule:
    ''{ match_key = "${luaEscape rule.matchKey}", match_value = "${luaEscape rule.matchValue}", target = "${luaEscape rule.target}" }'';

  luaRulesTable =
    rules: "{\n" + lib.concatMapStringsSep ",\n" (rule: "  " + luaRuleEntry rule) rules + "\n}";

  mkAppSinkTargetScript = rules: ''
    lutils = require ("linking-utils")
    cutils = require ("common-utils")
    log = Log.open_topic ("s-linking")

    local rules = ${luaRulesTable rules}

    SimpleEventHook {
      name = "linking/nxcore-app-sink-target",
      before = "linking/find-defined-target",
      interests = {
        EventInterest {
          Constraint { "event.type", "=", "select-target" },
        },
      },
      execute = function (event)
        local source, om, si, si_props, si_flags, target =
            lutils:unwrap_select_target_event (event)

        if target then
          return
        end

        local target_value = nil
        for _, rule in ipairs (rules) do
          if si_props [rule.match_key] == rule.match_value then
            target_value = rule.target
            break
          end
        end

        if not target_value then
          return
        end

        for lnkbl in om:iterate { type = "SiLinkable" } do
          local target_props = lnkbl.properties
          if target_props ["node.name"] == target_value and
              target_props ["item.node.direction"] == cutils.getTargetDirection (si_props) and
              lutils.canLink (si_props, lnkbl) then
            log:info (si, string.format ("nxcore: routing %s to %s",
                tostring (si_props ["node.name"]), target_value))
            event:set_data ("target", lnkbl)
            break
          end
        end
      end
    }:register ()
  '';
in
{
  name = "pipewire";

  group = "sound";
  input = "linux";

  options = {
    defaultSink = lib.mkOption {
      type = lib.types.enum [
        "headset"
        "speaker"
      ];
      default = "speaker";
      description = "Preferred sink to enforce as the system default sink";
    };

    speakerSinkID = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Sink node name identifying the speaker output device";
    };

    headsetSinkID = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Sink node name identifying the headset output device";
    };

    defaultSourceID = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Source node name to enforce as the system default microphone";
    };

    rules = lib.mkOption {
      default = { };
      description = "Stream matching rules that route specific applications to the speaker or headset sink";
      type = lib.types.submodule {
        options = {
          headset = lib.mkOption {
            default = { };
            description = "Stream match rules routed to the headset sink";
            type = lib.types.submodule {
              options = {
                nodeNames = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Stream node names matched for this rule";
                };
                binary = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Application process binary names matched for this rule";
                };
              };
            };
          };
          speaker = lib.mkOption {
            default = { };
            description = "Stream match rules routed to the speaker sink";
            type = lib.types.submodule {
              options = {
                nodeNames = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Stream node names matched for this rule";
                };
                binary = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Application process binary names matched for this rule";
                };
              };
            };
          };
        };
      };
    };
  };

  module = {
    enabled = config: {
      nx.linux.desktop.niri.autoTiler.ignoredAppIds = [ "org.pulseaudio.pavucontrol" ];
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
          tag = "pipewire";
          string = "spa\\.alsa:.*follower avail:[0-9]+ delay:[0-9]+ target:[0-9]+ thr:[0-9]+, resync";
          user = true;
          unitless = true;
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
        {
          tag = "pipewire";
          string = "pw\\.context: ";
          user = true;
          unitless = true;
        }
        {
          tag = "pipewire";
          string = "pw\\.link: .*no more input formats";
          user = true;
          unitless = true;
        }
        {
          tag = "wireplumber";
          string = "wp-proc-utils: failed to get .* for PID [0-9]+:.*No such file or directory";
          user = true;
          unitless = true;
        }
        {
          tag = "wireplumber";
          string = "GLib: GError set over the top of a previous GError";
          user = true;
          unitless = true;
        }
        {
          tag = "pipewire-pulse";
          string = "mod\\.protocol-pulse: setsockopt\\(SO_PRIORITY\\) failed: Bad file descriptor";
          user = true;
          unitless = true;
        }
        {
          tag = "pipewire-pulse";
          string = "mod\\.protocol-pulse: client 0x[0-9a-f]+: no peercred: Bad file descriptor";
          user = true;
          unitless = true;
        }
        {
          tag = "pipewire-pulse";
          string = "mod\\.protocol-pulse: \\[PulseAudio Volume Control\\] timeout on stream 0x[0-9a-f]+ channel:[0-9]+";
          user = true;
          unitless = true;
        }
        {
          tag = "pipewire-pulse";
          string = "mod\\.protocol-pulse: 0x[0-9a-f]+: \\[PulseAudio Volume Control\\] underrun read:[0-9]+ avail:[0-9]+";
          user = true;
          unitless = true;
        }
        {
          tag = "pipewire";
          string = "mod\\.client-node: detected old client version [0-9]+";
          user = true;
          unitless = true;
        }
      ];
    };

    ifEnabled.common.browser.firefox.enabled = config: {
      nx.common.browser.firefox.lockedPreferences = {
        "media.webrtc.camera.allow-pipewire" = {
          Value = true;
          Status = "locked";
        };
      };
    };

    home =
      {
        config,
        defaultSink,
        speakerSinkID,
        headsetSinkID,
        defaultSourceID,
        ...
      }:
      let
        resolvedDefaultSink = resolveDefaultSink defaultSink speakerSinkID headsetSinkID;

        setDefaultDeviceScript =
          kind: device:
          pkgs.writeShellScript "set-default-${kind}" ''
            DEVICE_NAME="${device}"
            MAX_ATTEMPTS=45

            for i in $(${pkgs.coreutils}/bin/seq 1 $MAX_ATTEMPTS); do
              echo "Attempt $i/$MAX_ATTEMPTS: Checking for ${kind} $DEVICE_NAME"

              if ! ${pkgs.pulseaudio}/bin/pactl info >/dev/null 2>&1; then
                echo "PipeWire/PulseAudio not ready yet, waiting..."
              else
                if ${pkgs.pulseaudio}/bin/pactl list ${kind}s short | ${pkgs.gnugrep}/bin/grep -q "$DEVICE_NAME"; then
                  echo "Found ${kind} $DEVICE_NAME, setting as default"
                  ${pkgs.pulseaudio}/bin/pactl set-default-${kind} "$DEVICE_NAME"
                  exit $?
                else
                  echo "PipeWire ready, but ${kind} not found, waiting 1 second..."
                fi
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done

            echo "${kind} $DEVICE_NAME not found after $MAX_ATTEMPTS attempts"
            exit 1
          '';

        mkSetDefaultDeviceService = kind: device: {
          Unit = {
            Description = "Set default audio ${kind}";
            After = [
              "graphical-session.target"
              "pipewire-pulse.service"
            ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${setDefaultDeviceScript kind device}";
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
      in
      lib.mkMerge [
        (lib.mkIf (resolvedDefaultSink != null) {
          systemd.user.services.set-default-sink = mkSetDefaultDeviceService "sink" resolvedDefaultSink;
        })
        (lib.mkIf (defaultSourceID != null) {
          systemd.user.services.set-default-source = mkSetDefaultDeviceService "source" defaultSourceID;
        })
        {
          home.file."${defs.binDir}/nx-list-audio-devices" = {
            executable = true;
            text = ''
              #!/usr/bin/env bash

              DEFAULT_SINK=$(${pkgs.pulseaudio}/bin/pactl info | ${pkgs.gnugrep}/bin/grep "^Default Sink:" | ${pkgs.coreutils}/bin/cut -d' ' -f3-)
              DEFAULT_SOURCE=$(${pkgs.pulseaudio}/bin/pactl info | ${pkgs.gnugrep}/bin/grep "^Default Source:" | ${pkgs.coreutils}/bin/cut -d' ' -f3-)

              echo "Output devices (sinks):"
              ${pkgs.pulseaudio}/bin/pactl list sinks short | while read -r _ name _; do
                if [ "$name" = "$DEFAULT_SINK" ]; then
                  echo "  [default] $name"
                else
                  echo "            $name"
                fi
              done

              echo ""
              echo "Input devices (sources):"
              ${pkgs.pulseaudio}/bin/pactl list sources short | ${pkgs.gnugrep}/bin/grep -v '\.monitor\b' | while read -r _ name _; do
                if [ "$name" = "$DEFAULT_SOURCE" ]; then
                  echo "  [default] $name"
                else
                  echo "            $name"
                fi
              done
            '';
          };
        }
      ];

    linux.system =
      {
        config,
        defaultSink,
        speakerSinkID,
        headsetSinkID,
        defaultSourceID,
        rules,
        ...
      }:
      let
        resolvedDefaultSink = resolveDefaultSink defaultSink speakerSinkID headsetSinkID;

        appSinkMatchRules =
          mkSinkMatchRules headsetSinkID rules.headset ++ mkSinkMatchRules speakerSinkID rules.speaker;
      in
      {
        services.pulseaudio.enable = lib.mkForce false;

        security.rtkit.enable = true;

        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          jack.enable = true;
          pulse.enable = true;

          extraConfig.pipewire-pulse = lib.mkMerge [
            (lib.mkIf (resolvedDefaultSink != null) {
              "99-default-sink" = {
                "context.exec" = [
                  {
                    path = "${pkgs.pulseaudio}/bin/pactl";
                    args = "set-default-sink ${resolvedDefaultSink}";
                  }
                ];
              };
            })
            (lib.mkIf (defaultSourceID != null) {
              "99-default-source" = {
                "context.exec" = [
                  {
                    path = "${pkgs.pulseaudio}/bin/pactl";
                    args = "set-default-source ${defaultSourceID}";
                  }
                ];
              };
            })
          ];

          wireplumber.extraScripts = lib.mkIf (appSinkMatchRules != [ ]) {
            "nxcore/app-sink-target.lua" = mkAppSinkTargetScript appSinkMatchRules;
          };

          wireplumber.extraConfig."52-app-sink-target" = lib.mkIf (appSinkMatchRules != [ ]) {
            "wireplumber.components" = [
              {
                name = "nxcore/app-sink-target.lua";
                type = "script/lua";
                provides = "nxcore.app-sink-target";
              }
            ];
            "wireplumber.profiles".main."nxcore.app-sink-target" = "required";
          };
        };
      };
  };
}
