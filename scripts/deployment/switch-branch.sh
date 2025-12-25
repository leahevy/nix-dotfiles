#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "switch-branch"
parse_git_args "$@"

BRANCH_TO_SWITCH=""
for arg in "${EXTRA_ARGS[@]}"; do
    if [[ "$arg" != --* && "$arg" != -* ]]; then
        if [[ -z "$BRANCH_TO_SWITCH" ]]; then
            BRANCH_TO_SWITCH="$arg"
        else
            echo -e "${RED}Error: Multiple branch names provided. Please provide only one branch name to switch to.${RESET}"
            exit 1
        fi
    fi
done
if [[ -z "$BRANCH_TO_SWITCH" ]]; then
    echo -e "${RED}Error: No branch name provided. Please provide a branch name to switch to.${RESET}"
    exit 1
fi

check_repo_safety() {
    local repo_path="$1"
    local repo_name="$2"

    pushd "$repo_path" > /dev/null

    local modified_files
    modified_files=$(git status --porcelain | grep -E '^(M |.M|D |.D|R |.R|C |.C|A |.A|U |.U|AA|DD|AU|UA|DU|UD)')

    if [[ -n "$modified_files" ]]; then
        echo -e "${RED}Error: Cannot switch branches in $repo_name repository. You have uncommitted changes to existing files:${RESET}"
        echo "$modified_files"
        popd > /dev/null
        return 1
    fi

    local current_branch
    current_branch=$(git branch --show-current)

    if [[ "$current_branch" != "main" && "$BRANCH_TO_SWITCH" != "main" ]]; then
        echo -e "${RED}Error: Cannot switch from feature branch '${current_branch}' to feature branch '${BRANCH_TO_SWITCH}' in $repo_name repository.${RESET}"
        echo -e "${YELLOW}You can only switch:${RESET}"
        echo -e "${YELLOW}  - From main branch to any branch${RESET}"
        echo -e "${YELLOW}  - From any branch back to main branch${RESET}"
        popd > /dev/null
        return 1
    fi

    popd > /dev/null
    return 0
}

switch_branch_in_repo() {
    local repo_path="$1"
    local repo_name="$2"

    pushd "$repo_path" > /dev/null

    local current_branch
    current_branch=$(git branch --show-current)

    if [[ "$current_branch" == "$BRANCH_TO_SWITCH" ]]; then
        echo -e "${YELLOW}Already on branch '${current_branch}' in $repo_name repository.${RESET}"
        popd > /dev/null
        return 0
    fi

    if git show-ref --verify --quiet "refs/heads/$BRANCH_TO_SWITCH"; then
        echo -e "${GREEN}Switch to existing branch ${WHITE}$BRANCH_TO_SWITCH${RESET} in $repo_name repository ${WHITE}($repo_path)${RESET}..."
        git checkout "$BRANCH_TO_SWITCH"
    else
        echo -e "${GREEN}Create and switch to new branch ${WHITE}$BRANCH_TO_SWITCH${RESET} in $repo_name repository ${WHITE}($repo_path)${RESET}..."
        git checkout -b "$BRANCH_TO_SWITCH"
    fi

    popd > /dev/null
}

if [[ "$ONLY_CONFIG" != true ]]; then
    if ! check_repo_safety "." "main"; then
        exit 1
    fi
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if ! check_repo_safety "$CONFIG_DIR" "config"; then
        exit 1
    fi
fi

if [[ "$ONLY_CONFIG" != true ]]; then
    switch_branch_in_repo "." "main"
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if [[ "$ONLY_CONFIG" != true ]]; then
        echo
    fi
    switch_branch_in_repo "$CONFIG_DIR" "config"
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
