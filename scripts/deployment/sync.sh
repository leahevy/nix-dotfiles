#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "sync"

parse_common_deployment_args "$@"
check_git_worktrees_clean
verify_commits
check_deployment_conflicts "sync"

PROFILE="$(retrieve_active_profile)"


if [[ -e /etc/NIXOS ]]; then
  export_nixos_label

  nh os switch -H "$PROFILE" . -- --impure "${EXTRA_ARGS[@]:-}"
else
  nh home switch ".#homeConfigurations.$PROFILE.activationPackage" -b nix-rebuild.backup -- --impure "${EXTRA_ARGS[@]:-}"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  BREWFILE="$HOME/.config/homebrew/Brewfile"
  BREWFILE_ACTIVE="$HOME/.config/homebrew/Brewfile.active"

  if [[ -f "$BREWFILE" ]]; then
    if [[ ! -f "$BREWFILE_ACTIVE" ]]; then
      echo
      echo -e "${YELLOW}Brewfile created, you should run: ${GREEN}nx brew${YELLOW} to sync Homebrew packages${RESET}"
    elif [[ -f "$BREWFILE_ACTIVE" ]]; then
      CHECKSUM_NEW=$(shasum -a 256 "$BREWFILE" | cut -d' ' -f1)
      CHECKSUM_ACTIVE=$(shasum -a 256 "$BREWFILE_ACTIVE" | cut -d' ' -f1)

      if [[ "$CHECKSUM_NEW" != "$CHECKSUM_ACTIVE" ]]; then
        echo
        echo -e "${YELLOW}Brewfile was updated, you should run: ${GREEN}nx brew${RESET}"
      fi
    fi
  fi
fi
