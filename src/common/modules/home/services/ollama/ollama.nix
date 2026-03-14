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
  namespace = "home";

  settings = {
    host = "127.0.0.1";
    port = 11434;
    allowGPU = true;
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

  configuration =
    context@{ config, options, ... }:
    let
      ollamaHost = self.settings.host;
      ollamaPort = self.settings.port;
      allModels = [ self.settings.codingModel ] ++ self.settings.additionalModels;

      pullModelsScript = pkgs.writeShellScript "ollama-pull-models-worker" ''
        set -euo pipefail

        OLLAMA_HOST="${ollamaHost}"
        OLLAMA_PORT="${toString ollamaPort}"
        OLLAMA_URL="http://$OLLAMA_HOST:$OLLAMA_PORT"
        AVAILABILITY_CHECK_INTERVAL=5
        MODEL_PULL_RETRIES=3
        MODEL_PULL_RETRY_INTERVAL=10

        notify_user() {
          ${lib.optionalString self.isLinux ''
            local level="$1"
            local message="$2"
            if [ "$level" = "error" ]; then
              ${pkgs.util-linux}/bin/logger -p user.err -t nx-user-notify "$message"
            else
              ${pkgs.util-linux}/bin/logger -t nx-user-notify "$message"
            fi
          ''}
          :
        }

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
            notify_user "error" "Ollama|dialog-error: Failed to pull model $model"
          fi
        done

        FAILED_COUNT=''${#FAILED_MODELS[@]}
        SUCCESS_COUNT=$((TOTAL_MODELS - FAILED_COUNT))

        if [ $FAILED_COUNT -gt 0 ]; then
          echo "WARNING: Failed to pull the following models: ''${FAILED_MODELS[*]}"
          notify_user "error" "Ollama|dialog-warning: $SUCCESS_COUNT models ready, $FAILED_COUNT failed"
          exit 1
        fi

        echo "All models pulled successfully."
        notify_user "info" "Ollama|chat-symbolic: All $TOTAL_MODELS models ready"
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
    in
    {
      services.ollama = {
        enable = true;
        package = pkgs.ollama.override {
          acceleration =
            if !self.settings.allowGPU then
              false
            else if self.isLinux then
              "vulkan"
            else
              null;
        };
        host = ollamaHost;
        port = ollamaPort;
        environmentVariables = self.settings.environmentVariables;
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
          RemainAfterExit = true;
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
          LaunchOnlyOnce = true;
          StandardOutPath = "/tmp/ollama-pull-models.log";
          StandardErrorPath = "/tmp/ollama-pull-models.err";
        };
      };

      home.persistence."${self.persist}" = {
        directories = [ ".ollama" ];
        files = [ ];
      };
    };
}
