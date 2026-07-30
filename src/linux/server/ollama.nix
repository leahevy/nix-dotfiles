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
  thinkingTierModels = [
    "qwen3.5:0.8b"
    "qwen3.5:2b"
    "qwen3.5:4b"
    "qwen3.5:9b"
    "qwen3.5:27b"
  ];
  nonThinkingTierModels = [
    "qwen2.5:1.5b"
    "qwen2.5:3b"
    "qwen3:4b-instruct-2507"
    "qwen3:30b-a3b-instruct-2507"
    "qwen3:235b-a22b-instruct-2507"
  ];
  tierCount = lib.min (builtins.length thinkingTierModels) (builtins.length nonThinkingTierModels);
  tierModelsFor = cfg: if cfg.tierThinking then thinkingTierModels else nonThinkingTierModels;
  effectiveModelFor =
    cfg:
    if cfg.defaultModel != null then
      cfg.defaultModel
    else
      builtins.elemAt (tierModelsFor cfg) (cfg.modelTier - 1);
  allModelsFor = cfg: [ (effectiveModelFor cfg) ] ++ cfg.additionalModels;
  nxOllamaTestFor =
    cfg:
    pkgs.writeShellApplication {
      name = "nx-ollama-test";
      runtimeInputs = [
        pkgs.curl
        pkgs.jq
        pkgs.coreutils
      ];
      excludeShellChecks = [ "SC2016" ];
      text = ''
        baseUrl=${lib.escapeShellArg "http://127.0.0.1:${toString cfg.port}"}
        model=${lib.escapeShellArg (effectiveModelFor cfg)}

        if [ ! -t 0 ]; then
          prompt=$(cat)
        elif [ "$#" -eq 0 ]; then
          prompt="Reply with the single word: ok"
        else
          prompt="$*"
        fi

        curl -sS "$baseUrl/api/generate" \
          -H "Content-Type: application/json" \
          --data "$(jq -n --arg m "$model" --arg p "$prompt" '{model: $m, prompt: $p, stream: false}')" \
          | jq -r '.response'
      '';
    };
in
{
  name = "ollama";
  description = "Ollama LLM server";

  group = "server";
  input = "linux";

  submodules = {
    linux.server.nginx = true;
  };

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "ollama";
      description = "Subdomain under baseDomain where the ollama API is served via nginx.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Local port the ollama server binds to on 127.0.0.1.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Primary model pulled on startup and intended as the client default, or null to select one by modelTier.";
    };

    modelTier = lib.mkOption {
      type = lib.types.ints.between 1 tierCount;
      default = 3;
      description = "Preset model tier used when defaultModel is null, from 1 (smallest and fastest) to ${toString tierCount} (largest and highest quality).";
    };

    tierThinking = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Select the reasoning qwen3.5 tier ladder instead of the non-thinking qwen2.5 and qwen3-instruct ladder used for modelTier.";
    };

    additionalModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra models to pull and allow in addition to the default model.";
    };

    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "-1";
      description = "Duration a model stays resident in memory, passed to OLLAMA_KEEP_ALIVE, with -1 meaning infinite.";
    };

    maxLoadedModels = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Maximum number of models kept loaded in memory at once passed to OLLAMA_MAX_LOADED_MODELS, or null to scale with the number of configured models.";
    };

    numParallel = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Maximum number of parallel requests per model, passed to OLLAMA_NUM_PARALLEL.";
    };

    contextLength = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 32768;
      description = "Context window length in tokens passed to OLLAMA_CONTEXT_LENGTH, defaulting to 32768 which fits the default 4b tier under the memory cap, or null to use the ollama default.";
    };

    syncModels = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Remove any installed model not declared in defaultModel or additionalModels.";
    };

    internalOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restrict the vhost to trusted internal clients using the nginx nx_is_internal variable.";
    };

    restrictManagementEndpoints = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Block the ollama model-management endpoints (pull, push, create, delete, copy, blobs) at nginx so clients cannot pull other models.";
    };

    memoryMax = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "50%";
      description = "Systemd MemoryMax cap for the ollama service as an absolute size or a percentage of host memory such as 50%, or null for no cap, with swap also disabled for the service whenever a cap is set.";
    };

    disableCloud = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable ollama cloud features (remote inference and web search) by setting OLLAMA_NO_CLOUD.";
    };

    flashAttention = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the experimental flash attention backend via OLLAMA_FLASH_ATTENTION, required for a quantized kvCacheType.";
    };

    kvCacheType = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "f16"
          "q8_0"
          "q4_0"
        ]
      );
      default = null;
      description = "K/V cache quantization type passed to OLLAMA_KV_CACHE_TYPE, or null for the ollama default, with q8_0 and q4_0 requiring flashAttention.";
    };

    maxQueue = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Maximum number of queued requests passed to OLLAMA_MAX_QUEUE, or null for the ollama default.";
    };

    loadTimeout = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Model load stall timeout passed to OLLAMA_LOAD_TIMEOUT, or null for the ollama default.";
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables merged into the ollama service environment.";
    };
  };

  module = {
    ifEnabled.linux.security.aide = {
      enabled = config: {
        nx.linux.security.aide.skipPaths = [ "/var/lib/ollama" ];
      };
    };

    linux.system =
      {
        config,
        port,
        keepAlive,
        maxLoadedModels,
        numParallel,
        contextLength,
        syncModels,
        memoryMax,
        disableCloud,
        flashAttention,
        kvCacheType,
        maxQueue,
        loadTimeout,
        environmentVariables,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        ollamaCfg = config.nx.linux.server.ollama;
        allModels = allModelsFor ollamaCfg;
      in
      {
        assertions = [
          {
            assertion = domain != null;
            message = "linux.server.ollama requires host.remote.baseDomain to be set!";
          }
          {
            assertion = config.nx.linux.security.letsencrypt.enable;
            message = "linux.server.ollama requires linux.security.letsencrypt to be enabled!";
          }
          {
            assertion = domain == null || (config.nx.linux.security.letsencrypt.dnsCerts ? ${domain});
            message = "linux.server.ollama requires linux.security.letsencrypt to provide a dnsCert for the base domain!";
          }
          {
            assertion = kvCacheType == null || kvCacheType == "f16" || flashAttention;
            message = "linux.server.ollama kvCacheType q8_0 and q4_0 require flashAttention to be enabled!";
          }
        ];

        sops.secrets."ollama-api-key" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "ollama-api-key";
          owner = "root";
          mode = "0400";
        };

        services.ollama = {
          enable = true;
          package = pkgs.ollama;
          user = "ollama";
          group = "ollama";
          host = "127.0.0.1";
          port = port;
          openFirewall = false;
          loadModels = allModels;
          syncModels = syncModels;
          environmentVariables = {
            OLLAMA_KEEP_ALIVE = keepAlive;
            OLLAMA_MAX_LOADED_MODELS = toString (
              if maxLoadedModels != null then maxLoadedModels else builtins.length allModels
            );
            OLLAMA_NUM_PARALLEL = toString numParallel;
          }
          // lib.optionalAttrs (contextLength != null) {
            OLLAMA_CONTEXT_LENGTH = toString contextLength;
          }
          // lib.optionalAttrs disableCloud {
            OLLAMA_NO_CLOUD = "1";
          }
          // lib.optionalAttrs flashAttention {
            OLLAMA_FLASH_ATTENTION = "1";
          }
          // lib.optionalAttrs (kvCacheType != null) {
            OLLAMA_KV_CACHE_TYPE = kvCacheType;
          }
          // lib.optionalAttrs (maxQueue != null) {
            OLLAMA_MAX_QUEUE = toString maxQueue;
          }
          // lib.optionalAttrs (loadTimeout != null) {
            OLLAMA_LOAD_TIMEOUT = loadTimeout;
          }
          // environmentVariables;
        };

        systemd.services.ollama.serviceConfig = {
          DynamicUser = lib.mkForce false;
          MemoryMax = lib.mkIf (memoryMax != null) memoryMax;
          MemorySwapMax = lib.mkIf (memoryMax != null) "0";
          Restart = lib.mkDefault "on-failure";
          RestartSec = lib.mkDefault "1s";
          RestartMaxDelaySec = lib.mkDefault "2h";
          RestartSteps = lib.mkDefault "10";
          OOMPolicy = lib.mkDefault "kill";
        };

        environment.persistence."${self.persist}" = {
          directories = [ "/var/lib/ollama" ];
        };

        systemd.tmpfiles.settings."10-ollama" = {
          "/var/lib/ollama".d = {
            mode = "0750";
            user = "ollama";
            group = "ollama";
          };
          "/var/lib/ollama/models".d = {
            mode = "0750";
            user = "ollama";
            group = "ollama";
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}/var/lib/ollama".d = {
            mode = "0750";
            user = "ollama";
            group = "ollama";
          };
          "${self.persist}/var/lib/ollama/models".d = {
            mode = "0750";
            user = "ollama";
            group = "ollama";
          };
        };
      };

    linux.home =
      {
        port,
        defaultModel,
        modelTier,
        tierThinking,
        ...
      }:
      {
        home.sessionVariables.OLLAMA_HOST = "127.0.0.1:${toString port}";
        home.packages = [
          (nxOllamaTestFor {
            inherit
              port
              defaultModel
              modelTier
              tierThinking
              ;
          })
        ];
      };

    ifEnabled.linux.server.nginx = {
      linux.system =
        {
          config,
          subdomain,
          port,
          internalOnly,
          restrictManagementEndpoints,
          ...
        }:
        let
          domain = self.host.remote.baseDomain;
          blockedLocations = lib.optionalAttrs restrictManagementEndpoints {
            "= /api/pull" = {
              return = "403";
            };
            "= /api/push" = {
              return = "403";
            };
            "= /api/create" = {
              return = "403";
            };
            "= /api/delete" = {
              return = "403";
            };
            "= /api/copy" = {
              return = "403";
            };
            "/api/blobs" = {
              return = "403";
            };
          };
          authScript = pkgs.writeShellScript "nx-ollama-nginx-auth" ''
            set -euo pipefail
            umask 027
            {
              printf 'map $http_authorization $ollama_auth_ok {\n  default 0;\n  "Bearer '
              ${pkgs.coreutils}/bin/tr -d '\r\n' < ${
                lib.escapeShellArg config.sops.secrets."ollama-api-key".path
              }
              printf '" 1;\n}\n'
            } > /run/nx-ollama-auth/map.conf
          '';
        in
        {
          services.nginx.commonHttpConfig = "include /run/nx-ollama-auth/map.conf;";

          systemd.services.nx-ollama-nginx-auth = {
            description = "Render Ollama nginx Bearer auth map";
            before = [ "nginx.service" ];
            wantedBy = [ "nginx.service" ];
            partOf = [ "nginx.service" ];
            restartTriggers = [ config.sops.secrets."ollama-api-key".sopsFile ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              Group = config.services.nginx.group;
              RuntimeDirectory = "nx-ollama-auth";
              RuntimeDirectoryMode = "0750";
              ExecStart = toString authScript;
            };
          };

          systemd.services.nginx = {
            after = [ "nx-ollama-nginx-auth.service" ];
            wants = [ "nx-ollama-nginx-auth.service" ];
            restartTriggers = [ config.sops.secrets."ollama-api-key".sopsFile ];
          };

          services.nginx.virtualHosts."${subdomain}.${domain}" = {
            useACMEHost = domain;
            forceSSL = true;
            locations = blockedLocations // {
              "/" = {
                proxyPass = "http://127.0.0.1:${toString port}";
                proxyWebsockets = true;
                recommendedProxySettings = false;
                extraConfig = ''
                  ${lib.optionalString internalOnly "if ($nx_is_internal = 0) { return 403; }"}
                  if ($ollama_auth_ok = 0) { return 401; }
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
                  proxy_read_timeout 600s;
                  proxy_send_timeout 600s;
                  proxy_buffering off;
                '';
              };
            };
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled =
        config:
        let
          port = toString config.nx.linux.server.ollama.port;
          models = allModelsFor config.nx.linux.server.ollama;
        in
        {
          nx.linux.server.healthchecks.requireServicesUp = [ "ollama.service" ];
          nx.linux.server.healthchecks.regularHealthChecks."+53 - Ollama API reachable" = ''
            _code=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
              "http://127.0.0.1:${port}/api/tags" 2>/dev/null || true)
            printf 'http://127.0.0.1:${port}/api/tags -> HTTP %s\n' "$_code" >&3
            [[ "$_code" =~ ^2 ]]
          '';
          nx.linux.server.healthchecks.regularHealthChecks."R+54 - Ollama configured models present" = ''
            _tags=$(${pkgs.curl}/bin/curl -s --max-time 10 "http://127.0.0.1:${port}/api/tags" 2>/dev/null || true)
            _missing=""
            for _m in ${lib.concatStringsSep " " (map lib.escapeShellArg models)}; do
              if ! printf '%s' "$_tags" | ${pkgs.jq}/bin/jq -e --arg m "$_m" '.models[]? | select(.name == $m)' >/dev/null 2>&1; then
                _missing="$_missing $_m"
              fi
            done
            printf 'configured models present -> missing=[%s]\n' "''${_missing# }" >&3
            [ -z "$_missing" ]
          '';
        };
    };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          subdomain = config.nx.linux.server.ollama.subdomain;
        in
        {
          nx.linux.server.dashboard.services = [
            {
              name = "Ollama";
              href = "https://${subdomain}.${domain}";
              description = "Local LLM engine";
              icon = "ollama";
              group = "admin";
            }
          ];
        };
    };
  };
}
