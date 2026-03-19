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
  name = "mcp-server";

  group = "nvim";
  input = "common";
  namespace = "home";

  settings = {
    dirMappings = {
      "~/.config/nx/nxconfig" = "~/.config/nx/nxcore";
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      mcp-neovim-server = pkgs.buildNpmPackage rec {
        pname = "mcp-neovim-server";
        version = "0.5.5";

        src = pkgs.fetchFromGitHub {
          owner = "bigcodegen";
          repo = "mcp-neovim-server";
          rev = "9076bbb34a08f44a743ad66c78638ef22da58ab0";
          hash = "sha256-rSnizEKhuvHSxwmOG/V+QIaAx7TCN1lGUiP28usaeng=";
        };

        npmDepsHash = "sha256-vqRPSO8Oji0HvTMBDUXrhQxe+M6cfFpALnqsBfrctPQ=";

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          cp -r . $out/
          makeWrapper ${pkgs.nodejs}/bin/node $out/bin/mcp-neovim-server \
            --add-flags $out/build/index.js
          runHook postInstall
        '';

        nativeBuildInputs = [ pkgs.makeWrapper ];

        meta = with lib; {
          description = "Control Neovim using Model Context Protocol (MCP) and the official neovim/node-client JavaScript library";
          homepage = "https://github.com/bigcodegen/mcp-neovim-server";
          license = licenses.mit;
          maintainers = [ ];
          platforms = platforms.all;
        };
      };
    in
    {
      home.packages = [ mcp-neovim-server ];

      home.file.".local/bin/mcp-neovim-server-wrapper" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          declare -A DIR_MAPPINGS=(
            ${lib.concatStringsSep "\n            " (
              lib.mapAttrsToList (k: v: ''["${k}"]="${v}"'') self.settings.dirMappings
            )}
          )

          expand_tilde() {
            local path="$1"
            if [[ "$path" == "~" ]]; then
              echo "$HOME"
            elif [[ "$path" =~ ^~/ ]]; then
              echo "$HOME''${path:1}"
            else
              echo "$path"
            fi
          }

          find_nvim_socket() {
            local current_dir="$PWD"

            for key in "''${!DIR_MAPPINGS[@]}"; do
              local expanded_key=$(expand_tilde "$key")
              if [[ "$current_dir" == "$expanded_key" ]]; then
                local mapped_dir=$(expand_tilde "''${DIR_MAPPINGS[$key]}")
                if [[ -S "$mapped_dir/.nvim.socket" ]]; then
                  echo "$mapped_dir/.nvim.socket"
                  return 0
                fi
              fi
            done

            while [[ "$current_dir" != "/" ]]; do
              if [[ -S "$current_dir/.nvim.socket" ]]; then
                echo "$current_dir/.nvim.socket"
                return 0
              fi
              current_dir=$(dirname "$current_dir")
            done

            return 1
          }

          SOCKET_PATH=""
          if SOCKET_PATH=$(find_nvim_socket); then
            echo "Found nvim socket: $SOCKET_PATH" >&2
          else
            SOCKET_PATH="/tmp/nvim-''${USER}.socket"
            echo "No local socket found, using fallback: $SOCKET_PATH" >&2
          fi

          export NVIM_SOCKET_PATH="$SOCKET_PATH"
          exec mcp-neovim-server "$@"
        '';
      };
    };
}
