#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "bump"
check_deployment_conflicts "bump"

unpushed=$(git -C "$NXCORE_DIR" log origin/HEAD..HEAD --oneline 2>/dev/null || true)
if [[ -n "$unpushed" ]]; then
    echo -e "${YELLOW}Warning: nxcore has unpushed commits:${RESET}"
    echo
    echo "$unpushed" | while IFS= read -r line; do
        echo -e "  ${WHITE}$line${RESET}"
    done
    echo
    echo -e "${YELLOW}Bumping now will lock to the current remote HEAD, not your local commits.${RESET}"
    echo
    echo -e -n "${CYAN}Bump anyway? [${GREEN}y${CYAN}/${RED}N${CYAN}]${RESET} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborting. Push nxcore first, then run bump again.${RESET}"
        exit 1
    fi
fi

echo -e "Bumping ${WHITE}core${RESET} input of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
nix flake update core

use_dir="$CONFIG_DIR"
if [[ -d "$CONFIG_DIR/.git" && -d "$NXCORE_DIR/.git" ]]; then
    config_timestamp=$(get_latest_commit_timestamp "$CONFIG_DIR")
    core_timestamp=$(get_latest_commit_timestamp "$NXCORE_DIR")
    if [[ "$core_timestamp" -gt "$config_timestamp" ]]; then
        use_dir="$NXCORE_DIR"
    fi
elif [[ -d "$NXCORE_DIR/.git" ]]; then
    use_dir="$NXCORE_DIR"
fi

commit_msg=$(git -C "$use_dir" log -1 --pretty=format:"%s" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g' | awk '{if(length($0)>25) print substr($0,1,24)"-"; else print $0}' | sed 's/--$/-/')
label="$(git -C "$use_dir" log -1 --pretty=format:"$(git -C "$use_dir" branch --show-current).%cd.${commit_msg}" --date=format:'%d-%m-%y.%H:%M' | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9:_.-]//g')"
echo "$label" > "$CONFIG_DIR/.label"
echo -e "Generated label ${WHITE}$label${RESET}"
