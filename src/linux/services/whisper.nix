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
  modelHashes = {
    "tiny" = "088vdsf93cfirmx8nrr1h99pl2a5aq9jm38w6i3av6g5w54f01xy";
    "tiny-q5_1" = "1my3d6sd2yx9plvn4mzr5y3hf02jgccl79rikrl1bjm3imb111w1";
    "tiny-q8_0" = "1jhw5p240p5114dq460y8q88339biap42jvfzzi361zmscsmh262";
    "base" = "1zifp9gk9220vysx8a00mzf2sy05ni4l6crx95baivhlvp1mpvb0";
    "base-q5_1" = "16483bq93icwmhzz42rpphrl8phr8dm5qzjd005g7rmdabj1lbs2";
    "base-q8_0" = "1ndprdkvbi8aj37xmyqim6znp9brvps5985dgq5ql13ydslbjxy5";
    "small" = "0ywqxbziyp2bv72riyjpw4brk9v46d4cfbjfwqvvjrrq0srakqqv";
    "small-q5_1" = "1fqi0h90ig4ifpyb44cfc7dmnndv2vy5mr9g22yng9fp6nly91df";
    "small-q8_0" = "17vpgwqpgwa3qq96hh20jpnbarxqacgzh13czbaljq2ynq1gpj29";
    "medium" = "02322nffggmx3fqz0g0fw77bcwqnkysyir5l6x03k1jzxsnxa53c";
    "medium-q5_0" = "03r26hxpnpi3iwzz932ks2hgnpvqxgrfxhr38zn1i9n3h2rs9zhr";
    "medium-q8_0" = "00k5x9fhj0rfxv9i7ql7ir72vl5linb9ccs469124z8nwk5zz8a2";
    "large-v1" = "0gdm7g4gd3qiwcvk5cxn70295yl105v8dpfspl304paj20dg96bx";
    "large-v2" = "11wlk4zis1vnwf09xcbf4i943wrmp6w1ahgkd95pg0hcskj3yhls";
    "large-v2-q5_0" = "1wpnf2plpgrf0i3d03mx63mr7wra617p73gyq7dk0i8y48vlh89s";
    "large-v2-q8_0" = "133yfcs7di2l2zld9malvzx2fzl0s4xsigw5h9facil2i5nlxxgy";
    "large-v3" = "1qnijhsv47x1vx2vixy4jr8n0k6q8ham9ggrqh1m53dr82s85lb4";
    "large-v3-q5_0" = "1lcav7n277z1dm0ax7vksnmq1iyq99h006cxm3xbb0rzzzn9amyp";
    "large-v3-turbo" = "0sdwwblbfy9qjkjjxxvyfn47rx3y6pm1wfdcjfcidsrq9mvhziqz";
    "large-v3-turbo-q5_0" = "1qm7zxamlvac564c3270wqqqks5wc7532q3fqi01zbfmkiq22hir";
    "large-v3-turbo-q8_0" = "18arw8jbwpyggv0j6k5cf7n0964rafr5km7hw7hrsg3726fbczii";
  };

  vadModelHashes = {
    "silero-v5.1.2" = "29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf";
    "silero-v6.2.0" = "2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987";
  };

  serviceName = "nx-whisper";

  mkWhisper =
    config:
    let
      cfg = config.nx.linux.services.whisper;

      modelFileName = "ggml-${cfg.model}.bin";
      modelUrl = "${cfg.baseUrl}/resolve/${cfg.revision}/${modelFileName}";

      fetchedModel = pkgs.fetchurl {
        name = modelFileName;
        url = modelUrl;
        sha256 = if cfg.modelSha256 != null then cfg.modelSha256 else modelHashes.${cfg.model};
      };

      modelPath = if cfg.modelFile != null then "${cfg.modelFile}" else "${fetchedModel}";

      vadModelFileName = "ggml-${cfg.vad.model}.bin";
      vadModelUrl = "${cfg.vad.baseUrl}/resolve/${cfg.vad.revision}/${vadModelFileName}";

      fetchedVadModel = pkgs.fetchurl {
        name = vadModelFileName;
        url = vadModelUrl;
        sha256 =
          if cfg.vad.modelSha256 != null then cfg.vad.modelSha256 else vadModelHashes.${cfg.vad.model};
      };

      vadModelPath = if cfg.vad.modelFile != null then "${cfg.vad.modelFile}" else "${fetchedVadModel}";

      noiseArgs =
        lib.optionals cfg.suppressNonSpeechTokens [ "--suppress-nst" ]
        ++ lib.optionals cfg.vad.enable [
          "--vad"
          "--vad-model"
          vadModelPath
          "--vad-threshold"
          (toString cfg.vad.threshold)
        ];

      whisperCli = helpers.packageFile args cfg.package "bin/whisper-cli";
      whisperServer = helpers.packageFile args cfg.package "bin/whisper-server";
      curlBin = helpers.packageFile args pkgs.curl "bin/curl";

      maxDuration = toString cfg.maxDurationSeconds;

      oneshotList =
        audioFile:
        [
          whisperCli
          "--model"
          modelPath
          "--language"
          cfg.language
          "--threads"
          (toString cfg.threads)
          "--no-prints"
          "--no-timestamps"
        ]
        ++ noiseArgs
        ++ [
          "--file"
          audioFile
        ];

      serverList = audioFile: [
        curlBin
        "-fsS"
        "--max-time"
        (toString cfg.timeoutSeconds)
        "--unix-socket"
        cfg.server.socketPath
        "-F"
        "file=@${audioFile}"
        "-F"
        "language=${cfg.language}"
        "-F"
        "no_timestamps=true"
        "-F"
        "response_format=text"
        "http://localhost/inference"
      ];

      nxWhisperModelHash = pkgs.writeShellScriptBin "nx-whisper-model-hash" ''
        set -euo pipefail

        BASE_URL="${cfg.baseUrl}"

        if [[ "''${1:-}" == "--vad" ]]; then
            BASE_URL="${cfg.vad.baseUrl}"
            shift
        fi

        if [[ $# -lt 1 || $# -gt 2 ]]; then
            echo "Usage: nx-whisper-model-hash [--vad] <model> [ref]" >&2
            echo "Example: nx-whisper-model-hash small" >&2
            echo "Example: nx-whisper-model-hash --vad silero-v5.1.2" >&2
            echo "The model is the ggml model name without the ggml prefix and the bin suffix." >&2
            echo "With --vad the detection model repository is used and the output belongs under vad." >&2
            echo "The ref may be a branch, tag or short commit and defaults to main." >&2
            echo "It is always resolved to a full commit revision before pinning." >&2
            exit 1
        fi

        MODEL="$1"
        REF="''${2:-main}"

        if [[ "$REF" =~ ^[0-9a-f]{40}$ ]]; then
            REVISION="$REF"
        else
            case "$BASE_URL" in
                https://huggingface.co/*)
                    REPO_ID="''${BASE_URL#https://huggingface.co/}"
                    ;;
                *)
                    echo "Cannot resolve refs for $BASE_URL, pass a full commit revision!" >&2
                    exit 1
                    ;;
            esac
            REVISION=$(${helpers.packageFile args pkgs.curl "bin/curl"} -fsSL \
                "https://huggingface.co/api/models/''${REPO_ID}/revision/''${REF}" \
                | ${helpers.packageFile args pkgs.jq "bin/jq"} -r '.sha // empty')
        fi

        if [[ ! "$REVISION" =~ ^[0-9a-f]{40}$ ]]; then
            echo "Failed to resolve ref $REF in $BASE_URL to a full commit revision!" >&2
            exit 1
        fi

        MODEL_URL="$BASE_URL/resolve/''${REVISION}/ggml-''${MODEL}.bin"
        MODEL_SHA256=$(${pkgs.nix}/bin/nix-prefetch-url "$MODEL_URL" 2>/dev/null | ${pkgs.coreutils}/bin/tail -n1)

        ${pkgs.coreutils}/bin/cat <<MODELEOF
        model = "$MODEL";
        revision = "$REVISION";
        modelSha256 = "$MODEL_SHA256";
        MODELEOF
      '';
      transcribeList = if cfg.backend == "server" then serverList else oneshotList;

      wavPlaceholder = "@NX_WHISPER_WAV@";

      transcribeCommand = lib.concatStringsSep " " (
        map (
          arg: lib.concatStringsSep "\"$WAV\"" (map lib.escapeShellArg (lib.splitString wavPlaceholder arg))
        ) (transcribeList wavPlaceholder)
      );

      nxWhisperTranscribe = pkgs.writeShellScriptBin "nx-whisper-transcribe" ''
        set -euo pipefail

        if [[ $# -ne 1 ]]; then
            echo "Usage: nx-whisper-transcribe <audio-file>" >&2
            echo "Example: nx-whisper-transcribe voice.m4a" >&2
            echo "The audio file is transcoded to 16 kHz mono WAV and its transcript is printed." >&2
            exit 1
        fi

        SOURCE="$1"

        if [[ ! -f "$SOURCE" ]]; then
            echo "The audio file $SOURCE does not exist!" >&2
            exit 1
        fi

        WORKDIR=$(${helpers.packageFile args pkgs.coreutils "bin/mktemp"} -d)
        trap '${helpers.packageFile args pkgs.coreutils "bin/rm"} -rf "$WORKDIR"' EXIT

        WAV="$WORKDIR/audio.wav"

        ${helpers.packageFile args pkgs.ffmpeg-headless "bin/ffmpeg"} -nostdin -loglevel error \
            -i "$SOURCE" -t ${maxDuration} -ar 16000 -ac 1 -c:a pcm_s16le -f wav "$WAV"

        ${transcribeCommand}
      '';
    in
    {
      inherit
        modelPath
        oneshotList
        serverList
        whisperServer
        nxWhisperModelHash
        nxWhisperTranscribe
        noiseArgs
        transcribeList
        ;
    };
in
{
  name = "whisper";

  group = "services";
  input = "linux";

  description = "Local speech to text transcription backed by whisper.cpp with a pinned ggml model";

  options = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.whisper-cpp;
      description = "The whisper.cpp package providing whisper-cli and whisper-server";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://huggingface.co/ggerganov/whisper.cpp";
      description = "Base repository URL under which the ggml model files are hosted";
    };

    revision = lib.mkOption {
      type = lib.types.str;
      default = "5359861c739e955e79d9a303bcbc70fb988958b1";
      description = "Full commit revision of the model repository the model is fetched from";
    };

    model = lib.mkOption {
      type = lib.types.enum (lib.attrNames modelHashes);
      default = "small";
      description = "Multilingual ggml model to transcribe with, larger models are more accurate and slower";
    };

    modelSha256 = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Overrides the known hash of the selected model, only needed when pinning a revision whose model bytes differ";
    };

    modelFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a local ggml model file used instead of fetching the selected model";
    };

    language = lib.mkOption {
      type = lib.types.str;
      default = "en";
      description = "Spoken language code passed to whisper, auto detects the language per clip";
    };

    threads = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Number of threads used during transcription";
    };

    suppressNonSpeechTokens = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Drop the non speech markers whisper emits for background noise instead of putting them into the transcript";
    };

    vad = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Detect speech before decoding so silence cannot be hallucinated into text";
          };

          baseUrl = lib.mkOption {
            type = lib.types.str;
            default = "https://huggingface.co/ggml-org/whisper-vad";
            description = "Base repository URL under which the ggml voice activity detection models are hosted";
          };

          revision = lib.mkOption {
            type = lib.types.str;
            default = "9ffd54a1e1ee413ddf265af9913beaf518d1639b";
            description = "Full commit revision of the model repository the detection model is fetched from";
          };

          model = lib.mkOption {
            type = lib.types.enum (lib.attrNames vadModelHashes);
            default = "silero-v5.1.2";
            description = "Silero detection model deciding which parts of a clip contain speech";
          };

          modelSha256 = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Overrides the known hash of the selected detection model, only needed when pinning a revision whose model bytes differ";
          };

          modelFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Path to a local detection model file used instead of fetching the selected one";
          };

          threshold = lib.mkOption {
            type = lib.types.float;
            default = 0.5;
            description = "Confidence above which a chunk counts as speech, raise it against noisy recordings";
          };
        };
      };
      default = { };
      description = "Voice activity detection settings applying to both backends";
    };

    backend = lib.mkOption {
      type = lib.types.enum [
        "oneshot"
        "server"
      ];
      default = "server";
      description = "Keep a whisper-server resident with the model loaded or run whisper-cli once per clip";
    };

    server = lib.mkOption {
      type = lib.types.submodule {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            default = 8642;
            description = "Port the whisper server listens on inside its private network namespace, never reachable from the host";
          };

          socketPath = lib.mkOption {
            type = lib.types.str;
            default = "/run/${serviceName}.sock";
            description = "Unix socket through which the server is reached, its file permissions are the access control";
          };

          group = lib.mkOption {
            type = lib.types.str;
            default = "${serviceName}-access";
            description = "Group owning the unix socket, members of it may transcribe";
          };
        };
      };
      default = { };
      description = "Settings that only apply to the server backend";
    };

    timeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Maximum wall clock time a single transcription may take";
    };

    maxDurationSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Maximum amount of audio transcribed per clip, anything beyond it is cut off";
    };

    transcribeList = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo (lib.types.listOf lib.types.str));
      default = null;
      description = "Function taking a 16 kHz mono WAV path and returning the argv that prints its transcript to stdout";
    };

    resolvedModelFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Store path of the ggml model the configured backend loads";
    };
  };

  module = {
    ifEnabled.linux.server.healthchecks = {
      enabled =
        config:
        lib.mkIf (config.nx.linux.services.whisper.backend == "server") {
          nx.linux.server.healthchecks.requireServicesUp = [ "${serviceName}.service" ];
          nx.linux.server.healthchecks.regularHealthChecks."R+56 - Whisper server" = ''
            if ! _whisper_health=$(${helpers.packageFile args pkgs.curl "bin/curl"} -fsS --max-time 10 \
              --unix-socket ${config.nx.linux.services.whisper.server.socketPath} \
              "http://localhost/health" 2>&1); then
              printf 'whisper server: %s\n' "$_whisper_health" >&3
              exit 1
            fi
          '';
        };
    };

    linux.enabled =
      config:
      let
        whisper = mkWhisper config;
      in
      {
        nx.linux.services.whisper.transcribeList = whisper.transcribeList;
        nx.linux.services.whisper.resolvedModelFile = whisper.modelPath;
      };

    linux.system =
      {
        config,
        package,
        backend,
        server,
        threads,
        language,
        modelFile,
        modelSha256,
        ...
      }:
      let
        whisper = mkWhisper config;

        serverActive = backend == "server";

        proxyName = "${serviceName}-proxy";
      in
      {
        assertions = [
          {
            assertion = !(modelFile != null && modelSha256 != null);
            message = "The whisper module ignores modelSha256 while modelFile is set, drop one of them!";
          }
          {
            assertion = server.group != serviceName && server.group != proxyName;
            message = "The whisper socket group must differ from the unit names, the dynamic users of ${serviceName} and ${proxyName} claim those names!";
          }
        ];

        users.groups.${server.group} = lib.mkIf serverActive { };

        environment.systemPackages = [
          package
          pkgs.ffmpeg-headless
          whisper.nxWhisperModelHash
          whisper.nxWhisperTranscribe
        ];

        systemd.services.${serviceName} = lib.mkIf serverActive {
          description = "NX Whisper Transcription Server";
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            Restart = "always";
            RestartSec = "10";
            ExecStart = lib.concatStringsSep " " (
              [
                whisper.whisperServer
                "--host"
                "127.0.0.1"
                "--port"
                (toString server.port)
                "--model"
                whisper.modelPath
                "--threads"
                (toString threads)
                "--language"
                language
                "--no-timestamps"
              ]
              ++ whisper.noiseArgs
            );

            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictRealtime = true;
            RestrictNamespaces = true;
            LockPersonality = true;
            CapabilityBoundingSet = "";
            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
            IPAddressAllow = [
              "localhost"
            ];
            IPAddressDeny = "any";
            PrivateNetwork = true;
            UMask = "0077";
          };
        };

        systemd.sockets.${proxyName} = lib.mkIf serverActive {
          description = "NX Whisper Transcription Socket";
          wantedBy = [ "sockets.target" ];

          socketConfig = {
            ListenStream = server.socketPath;
            SocketUser = "root";
            SocketGroup = server.group;
            SocketMode = "0660";
          };
        };

        systemd.services.${proxyName} = lib.mkIf serverActive {
          description = "NX Whisper Transcription Socket Proxy";
          requires = [
            "${proxyName}.socket"
            "${serviceName}.service"
          ];
          after = [
            "${proxyName}.socket"
            "${serviceName}.service"
          ];

          unitConfig = {
            JoinsNamespaceOf = "${serviceName}.service";
          };

          serviceConfig = {
            Type = "notify";
            DynamicUser = true;
            Restart = "on-failure";
            RestartSec = "1";
            ExecStart = "${
              helpers.packageFile args pkgs.systemd "lib/systemd/systemd-socket-proxyd"
            } 127.0.0.1:${toString server.port}";

            NoNewPrivileges = true;
            PrivateNetwork = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictRealtime = true;
            RestrictNamespaces = true;
            LockPersonality = true;
            CapabilityBoundingSet = "";
            SystemCallArchitectures = "native";
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
            UMask = "0077";
          };
        };
      };
  };
}
