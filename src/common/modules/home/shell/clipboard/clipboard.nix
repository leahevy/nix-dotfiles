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
  name = "clipboard";

  group = "shell";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".local/bin/x" = {
        text = ''
          #!/usr/bin/env bash

          set -euo pipefail

          has_stdin() {
              [[ ! -t 0 ]]
          }

          copy_to_clipboard() {
              local content="$1"

              if [[ "$(uname)" == "Darwin" ]]; then
                  echo -n "$content" | pbcopy
                  echo "Copied with pbcopy" >&2
              elif [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
                  if command -v wl-copy >/dev/null 2>&1; then
                      echo -n "$content" | wl-copy
                      echo "Copied with wl-copy" >&2
                  else
                      echo "Error: wl-copy not found. Install wl-clipboard for Wayland support." >&2
                      exit 1
                  fi
              elif [[ -n "''${DISPLAY:-}" ]]; then
                  if command -v xclip >/dev/null 2>&1; then
                      echo -n "$content" | xclip -selection clipboard
                      echo "Copied with xclip" >&2
                  elif command -v xsel >/dev/null 2>&1; then
                      echo -n "$content" | xsel --clipboard --input
                      echo "Copied with xsel" >&2
                  else
                      echo "Error: Neither xclip nor xsel found. Install one for X11 clipboard support." >&2
                      exit 1
                  fi
              else
                  if [[ -t 2 ]]; then
                      local b64_content
                      b64_content=$(echo -n "$content" | base64 -w 0)
                      printf "\033]52;c;%s\007" "$b64_content" >&2
                      echo "Copied with OSC 52" >&2
                  else
                      echo "Error: No clipboard mechanism available. Supported: macOS (pbcopy), Wayland (wl-copy), X11 (xclip/xsel), Terminal (OSC 52)." >&2
                      exit 1
                  fi
              fi
          }

          paste_from_clipboard() {
              if [[ "$(uname)" == "Darwin" ]]; then
                  echo "Pasted with pbpaste" >&2
                  pbpaste
              elif [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
                  if command -v wl-paste >/dev/null 2>&1; then
                      echo "Pasted with wl-paste" >&2
                      wl-paste
                  else
                      echo "Error: wl-paste not found. Install wl-clipboard for Wayland support." >&2
                      exit 1
                  fi
              elif [[ -n "''${DISPLAY:-}" ]]; then
                  if command -v xclip >/dev/null 2>&1; then
                      echo "Pasted with xclip" >&2
                      xclip -selection clipboard -o
                  elif command -v xsel >/dev/null 2>&1; then
                      echo "Pasted with xsel" >&2
                      xsel --clipboard --output
                  else
                      echo "Error: Neither xclip nor xsel found. Install one for X11 clipboard support." >&2
                      exit 1
                  fi
              else
                  if [[ -t 2 ]]; then
                      echo "Warning: Terminal clipboard paste using OSC 52 requires terminal support and may not work reliably." >&2
                      printf "\033]52;c;?\007" >&2
                      echo "Error: OSC 52 paste is not reliably supported across terminals. Use a platform-specific clipboard tool." >&2
                      exit 1
                  else
                      echo "Error: No clipboard mechanism available. Supported: macOS (pbpaste), Wayland (wl-paste), X11 (xclip/xsel)." >&2
                      exit 1
                  fi
              fi
          }

          main() {
              if has_stdin; then
                  local content
                  content=$(cat)
                  copy_to_clipboard "$content"
              else
                  paste_from_clipboard
              fi
          }

          main "$@"
        '';
        executable = true;
      };
    };
}
