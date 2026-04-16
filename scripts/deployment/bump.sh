#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "bump"
check_deployment_conflicts "bump"

COMMIT=false
PUSH=false
while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        --commit)
            COMMIT=true
            shift
            ;;
        --push)
            PUSH=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option ${WHITE}${1:-}${RESET}"
            exit 1
            ;;
        *)
            echo -e "${RED}Unknown argument ${WHITE}${1:-}${RESET}"
            exit 1
            ;;
    esac
done

if [[ "$PUSH" == "true" ]]; then
    COMMIT=true
fi

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

if [[ "$COMMIT" == "true" ]] && ! git diff --quiet HEAD -- flake.lock .label; then
    echo -e "${YELLOW}Warning: flake.lock or .label already have local changes.${RESET}"
    echo -e -n "${CYAN}Commit bump anyway? [${GREEN}y${CYAN}/${RED}N${CYAN}]${RESET} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        COMMIT=false
    fi
fi

echo -e "${CYAN}Bumping core input...${RESET}"
nix flake update core 2> >(grep -v "warning: Git tree.*is dirty" >&2)
echo -e "Updated ${WHITE}core${RESET} flake lock"
echo

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
if [[ "$use_dir" == "$CONFIG_DIR" && -d "$NXCORE_DIR/.git" ]]; then
    config_last_msg=$(git -C "$CONFIG_DIR" log -1 --pretty=format:"%s")
    if [[ "$config_last_msg" == "Bump core at: "* ]]; then
        use_dir="$NXCORE_DIR"
    fi
fi

commit_msg=$(git -C "$use_dir" log -1 --pretty=format:"%s" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g' | awk '{if(length($0)>25) print substr($0,1,24)"-"; else print $0}' | sed 's/--$/-/')
label="$(git -C "$use_dir" log -1 --pretty=format:"$(git -C "$use_dir" branch --show-current).%cd.${commit_msg}" --date=format:'%d-%m-%y.%H:%M' | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9:_.-]//g')"
echo "$label" > "$CONFIG_DIR/.label"
echo -e "Generated label ${WHITE}$label${RESET}"
echo

if [[ "$COMMIT" == "true" ]] && ! git diff --quiet HEAD -- flake.lock .label; then
    if git diff --cached --quiet -- flake.lock .label; then
        STASH_POP="git stash pop --index"
    else
        STASH_POP="git stash pop"
    fi
    pre_stash=$(git rev-parse --verify refs/stash 2>/dev/null || echo "none")
    echo -e "${CYAN}Stashing other changes...${RESET}"
    git stash push --include-untracked -- ':(exclude)flake.lock' ':(exclude).label'
    post_stash=$(git rev-parse --verify refs/stash 2>/dev/null || echo "none")
    if [[ "$pre_stash" != "$post_stash" ]]; then
        # shellcheck disable=SC2064
        trap "$STASH_POP; cleanup_deployment_lock" EXIT
    fi
    echo

    echo -e "${CYAN}Committing bump...${RESET}"
    git add "$CONFIG_DIR/flake.lock" "$CONFIG_DIR/.label"
    git commit -m "Bump core at: $label"
    echo -e "Committed ${WHITE}flake.lock${RESET} and ${WHITE}.label${RESET}"
    echo

    if [[ "$PUSH" == "true" ]]; then
        echo -e "${CYAN}Pushing config...${RESET}"
        git push
        echo -e "Pushed ${WHITE}config${RESET}"
        echo
    fi
fi
