#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "config"

TARGET_DIR="$CONFIG_DIR"

if [[ -x "$HOME/.nix-profile/bin/fish" ]] && [[ -f "$HOME/.config/fish/config.fish" ]]; then
  CURRENT_SHELL="fish"
elif [[ -x "$HOME/.nix-profile/bin/zsh" ]] && [[ -f "$HOME/.config/zsh/.zshrc" ]]; then
  CURRENT_SHELL="zsh"
else
  CURRENT_SHELL="$(basename "$SHELL")"
fi

case "$CURRENT_SHELL" in
  bash)
    (cd "$TARGET_DIR" && exec "$SHELL" --rcfile <(echo "cd \"$TARGET_DIR\"") -i)
    ;;
  zsh)
    (cd "$TARGET_DIR" && exec "$SHELL" -i)
    ;;
  fish)
    (cd "$TARGET_DIR" && exec "$SHELL")
    ;;
  *)
    (cd "$TARGET_DIR" && exec "$SHELL" -i)
    ;;
esac
