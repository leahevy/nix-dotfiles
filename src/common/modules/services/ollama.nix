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
  name = "ollama";

  group = "services";
  input = "common";

  settings = {
    host = "127.0.0.1";
    port = 11434;
    allowGPU = true;
    keepAlive = "1h";
    gpuOverheadGB = 4;
    environmentVariables = { };
    codingModel = "qwen2.5-coder:7b";
    additionalModels = [ ];
  };

  assertions = [
    {
      assertion = !(self.darwin.isModuleEnabled "dev.ollama");
      message = "common ollama (home-manager service) and darwin ollama (homebrew) are mutually exclusive!";
    }
  ];

  on = {
    home =
      config:
      let
        ollamaHost = self.settings.host;
        ollamaPort = self.settings.port;
        allModels = [ self.settings.codingModel ] ++ self.settings.additionalModels;

        pullModelsScript = pkgs.writeShellScript "ollama-pull-models-worker" ''
          set -euo pipefail

          echo "=== Ollama pull-models started at $(date) ==="

          OLLAMA_HOST="${ollamaHost}"
          OLLAMA_PORT="${toString ollamaPort}"
          OLLAMA_URL="http://$OLLAMA_HOST:$OLLAMA_PORT"
          AVAILABILITY_CHECK_INTERVAL=5
          MODEL_PULL_RETRIES=3
          MODEL_PULL_RETRY_INTERVAL=10

          echo "Waiting for Ollama to be ready at $OLLAMA_URL..."

          while true; do
            if ${pkgs.curl}/bin/curl -sf "$OLLAMA_URL/api/tags" > /dev/null 2>&1; then
              echo "Ollama is ready."
              break
            fi
            echo "Ollama not ready yet. Retrying in $AVAILABILITY_CHECK_INTERVAL seconds..."
            ${if self.isLinux then "${pkgs.coreutils}/bin/sleep" else "sleep"} $AVAILABILITY_CHECK_INTERVAL
          done

          echo "Checking internet connectivity..."

          while true; do
            if ${pkgs.curl}/bin/curl -sf --connect-timeout 5 "https://registry.ollama.ai" > /dev/null 2>&1; then
              echo "Internet connection available."
              break
            fi
            echo "No internet connection. Retrying in $AVAILABILITY_CHECK_INTERVAL seconds..."
            ${if self.isLinux then "${pkgs.coreutils}/bin/sleep" else "sleep"} $AVAILABILITY_CHECK_INTERVAL
          done

          echo "Pulling models..."

          MODELS=(${lib.concatStringsSep " " (map (m: "\"${m}\"") allModels)})
          FAILED_MODELS=()
          TOTAL_MODELS=''${#MODELS[@]}

          for model in "''${MODELS[@]}"; do
            echo "Pulling model: $model"
            retries=0
            success=false

            while [ $retries -lt $MODEL_PULL_RETRIES ]; do
              if ${pkgs.ollama}/bin/ollama pull "$model"; then
                echo "Successfully pulled model: $model"
                success=true
                break
              else
                retries=$((retries + 1))
                if [ $retries -lt $MODEL_PULL_RETRIES ]; then
                  echo "Failed to pull model $model (attempt $retries/$MODEL_PULL_RETRIES). Retrying in $MODEL_PULL_RETRY_INTERVAL seconds..."
                  ${
                    if self.isLinux then "${pkgs.coreutils}/bin/sleep" else "sleep"
                  } $MODEL_PULL_RETRY_INTERVAL
                fi
              fi
            done

            if [ "$success" = false ]; then
              echo "ERROR: Failed to pull model $model after $MODEL_PULL_RETRIES attempts."
              FAILED_MODELS+=("$model")
              ${self.notifyUser {
                title = "Ollama";
                body = "Failed to pull model $model";
                icon = "dialog-error";
                urgency = "critical";
                validation = { inherit config; };
              }}
            fi
          done

          FAILED_COUNT=''${#FAILED_MODELS[@]}
          SUCCESS_COUNT=$((TOTAL_MODELS - FAILED_COUNT))

          if [ $FAILED_COUNT -gt 0 ]; then
            echo "WARNING: Failed to pull the following models: ''${FAILED_MODELS[*]}"
            ${self.notifyUser {
              title = "Ollama";
              body = "$SUCCESS_COUNT models ready, $FAILED_COUNT failed";
              icon = "dialog-warning";
              urgency = "critical";
              validation = { inherit config; };
            }}
            exit 1
          fi

          echo "All models pulled successfully."
          ${self.notifyUser {
            title = "Ollama";
            body = "All $TOTAL_MODELS models ready";
            icon = "chat-symbolic";
            urgency = "normal";
            validation = { inherit config; };
          }}
        '';

        triggerScript = pkgs.writeShellScriptBin "ollama-pull-models" (
          if self.isDarwin then
            ''
              #!/bin/bash
              set -euo pipefail
              echo "Restarting ollama-pull-models launchd agent..."
              launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.ollama-pull-models"
            ''
          else
            ''
              #!/bin/bash
              set -euo pipefail
              echo "Restarting ollama-pull-models systemd service..."
              systemctl --user restart ollama-pull-models.service
            ''
        );
        gpuOverheadBytes = builtins.floor (self.settings.gpuOverheadGB * 1073741824);
      in
      {
        services.ollama = {
          enable = true;
          package = pkgs.ollama.override (
            {
              acceleration =
                if !self.settings.allowGPU then
                  false
                else if self.isLinux then
                  if self.linux.isModuleEnabled "graphics.nvidia-setup" then "cuda" else "vulkan"
                else
                  null;
            }
            // lib.optionalAttrs (self.variables.cudaArchitectures != [ ]) {
              cudaArches = self.variables.cudaArchitectures;
            }
          );
          host = ollamaHost;
          port = ollamaPort;
          environmentVariables = {
            OLLAMA_KEEP_ALIVE = self.settings.keepAlive;
          }
          // lib.optionalAttrs (self.settings.allowGPU && self.settings.gpuOverheadGB > 0) {
            OLLAMA_GPU_OVERHEAD = toString gpuOverheadBytes;
          }
          // self.settings.environmentVariables;
        };

        home.packages = [ triggerScript ];

        systemd.user.services.ollama-pull-models = lib.mkIf self.isLinux {
          Unit = {
            Description = "Pull Ollama models";
            After = [ "ollama.service" ];
            Requires = [ "ollama.service" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${pullModelsScript}";
          };
        };

        systemd.user.timers.ollama-pull-models = lib.mkIf self.isLinux {
          Unit = {
            Description = "Pull Ollama models after startup";
            X-Restart-Triggers = [ "${pullModelsScript}" ];
          };
          Timer = {
            OnActiveSec = "10s";
            Unit = "ollama-pull-models.service";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };

        launchd.agents.ollama-pull-models = lib.mkIf self.isDarwin {
          enable = true;
          config = {
            ProgramArguments = [ "${pullModelsScript}" ];
            RunAtLoad = true;
            StandardOutPath = "/tmp/ollama-pull-models.log";
            StandardErrorPath = "/tmp/ollama-pull-models.err";
          };
        };

        launchd.agents.ollama.config.RunAtLoad = lib.mkIf self.isDarwin true;

        home.persistence."${self.persist}" = {
          directories = [ ".ollama" ];
          files = [ ];
        };
      };
  };
}
