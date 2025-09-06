#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
simple_deployment_script_setup "spec"

HOME_MODE=false
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --home)
      HOME_MODE=true
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -e /etc/NIXOS ]]; then
  HOME_MODE=true
fi

if [[ "$HOME_MODE" = true ]]; then
  HM_PROFILE="$HOME/.local/state/nix/profiles/home-manager"
  if [[ ! -d "$HM_PROFILE" ]]; then
    HM_PROFILE="$HOME/.nix-profile"  # Fallback for older setups
  fi
  SPECIALISATION_DIR="$HM_PROFILE/specialisation"
  SPEC_TYPE="home-manager"
else
  SPECIALISATION_DIR="/nix/var/nix/profiles/system/specialisation"
  SPEC_TYPE="system"
fi

usage() {
  echo "Usage: $0 [--home] <command> [args]"
  echo ""
  echo "Options:"
  echo "  --home              Operate on home-manager specialisations instead of system"
  echo "                      (automatically enabled on non-NixOS systems)"
  echo ""
  echo "Commands:"
  echo "  list                List all available specialisations"
  echo "  switch <name>       Switch to the specified specialisation"
  echo "  reset               Reset to base configuration (home-manager only)"
  echo ""
}

cmd_list() {
  if [[ ! -d "$SPECIALISATION_DIR" ]]; then
    echo -e "${RED}No $SPEC_TYPE specialisations found (directory does not exist: ${WHITE}$SPECIALISATION_DIR${RED})${RESET}" >&2
    exit 1
  fi
  
  if [[ -z "$(ls -A "$SPECIALISATION_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}No $SPEC_TYPE specialisations available${RESET}"
    exit 0
  fi
  
  echo -e "Available ${WHITE}$SPEC_TYPE${RESET} specialisations:"
  ls "$SPECIALISATION_DIR"
}

cmd_switch() {
  local spec_name="${1:-}"
  
  if [[ -z "$spec_name" ]]; then
    echo -e "${RED}Usage: ${WHITE}$0 ${HOME_MODE:+--home }switch <specialisation-name>${RESET}" >&2
    echo >&2
    echo -e "Available ${WHITE}$SPEC_TYPE${RESET} specialisations:" >&2
    if [[ -d "$SPECIALISATION_DIR" ]]; then
      ls "$SPECIALISATION_DIR" >&2
    else
      echo "  (none - specialisation directory does not exist)" >&2
    fi
    exit 1
  fi
  
  local spec_path="$SPECIALISATION_DIR/$spec_name"
  
  if [[ ! -d "$spec_path" ]]; then
    echo -e "${RED}Error: $SPEC_TYPE specialisation '${WHITE}$spec_name${RED}' does not exist${RESET}" >&2
    echo >&2
    echo -e "Available ${WHITE}$SPEC_TYPE${RESET} specialisations:" >&2
    if [[ -d "$SPECIALISATION_DIR" ]]; then
      ls "$SPECIALISATION_DIR" >&2
    else
      echo "  (none - specialisation directory does not exist)" >&2
    fi
    exit 1
  fi
  
  local activate_script="$spec_path/activate"
  
  if [[ ! -x "$activate_script" ]]; then
    echo -e "${RED}Error: Activate script not found or not executable: ${WHITE}$activate_script${RESET}" >&2
    exit 1
  fi
  
  if [[ "$HOME_MODE" = true ]]; then
    mkdir -p ~/.local/cache/nx
    original_generation="$(readlink -f "$HM_PROFILE")"
    echo "$original_generation" > ~/.local/cache/nx/hm-original-generation
  fi
  
  echo -e "Switching to ${WHITE}$SPEC_TYPE${RESET} specialisation: ${WHITE}$spec_name${RESET}"
  if [[ "$HOME_MODE" = true ]]; then
    "$activate_script"
    echo ""
    echo "Note: Other home-manager specialisations may not be visible until you reset to base config."
    echo "Use '$0 --home reset' to return to base configuration."
  else
    sudo "$activate_script"
  fi
}

cmd_reset() {
  if [[ "$HOME_MODE" != true ]]; then
    echo -e "${RED}Reset command only available for home-manager specialisations. Use ${WHITE}--home${RED} flag.${RESET}" >&2
    exit 1
  fi
  
  local stored_generation=""
  if [[ -f ~/.local/cache/nx/hm-original-generation ]]; then
    stored_generation="$(cat ~/.local/cache/nx/hm-original-generation)"
  fi
  
  if [[ -n "$stored_generation" && -x "$stored_generation/activate" ]]; then
    echo -e "Resetting to stored original home-manager generation..."
    "$stored_generation/activate"
    rm -f ~/.local/cache/nx/hm-original-generation
    echo -e "${GREEN}Reset complete. All specialisations should now be visible again.${RESET}"
  else
    echo "No stored original generation found or invalid."
    echo "Falling back to current profile base (may not restore specialisations)..."
    
    local base_activate="$HM_PROFILE/activate"
    
    if [[ ! -x "$base_activate" ]]; then
      echo "Error: Base home-manager activate script not found: $base_activate" >&2
      echo "Try running 'nx sync' to rebuild home-manager." >&2
      exit 1
    fi
    
    "$base_activate"
    echo "Reset to current base complete, but specialisations may not be visible."
    echo "Consider running 'nx sync' to fully rebuild and restore specialisations."
  fi
}

case "${ARGS[0]:-}" in
  list)
    cmd_list
    ;;
  switch)
    cmd_switch "${ARGS[1]:-}"
    ;;
  reset)
    cmd_reset
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  "")
    echo -e "${RED}Error: Command required${RESET}" >&2
    usage >&2
    exit 1
    ;;
  *)
    echo -e "${RED}Error: Unknown command '${WHITE}${ARGS[0]:-}${RED}'${RESET}" >&2
    usage >&2
    exit 1
    ;;
esac
