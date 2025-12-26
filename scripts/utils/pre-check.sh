#!/usr/bin/env bash

RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
WHITE='\033[1;37m'
MAGENTA='\033[1;35m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
GRAY='\033[1;90m'
RESET='\033[0m'

get_nx_default() {
    local key="$1"
    case "$key" in
        "security.commitVerification.nxcore")
            echo "all"
            ;;
        "security.commitVerification.nxconfig")
            echo "all"
            ;;
        *)
            echo ""
            ;;
    esac
}

get_config_value() {
    local key="$1"
    local config_json="$2"
    local default_value="$(get_nx_default "$key")"

    if [[ -n "$config_json" ]] && command -v jq >/dev/null 2>&1; then
        echo "$config_json" | jq -r ".$key // \"$default_value\""
    else
        echo "$default_value"
    fi
}

check_config_directory() {
    local OPERATION="$1"
    local CONTEXT="${2:-deployment}"
    local REQUIRED="${3:-true}"

    if [[ -f /etc/NIXOS && "$CONTEXT" != "deployment" ]]; then
        NXCORE_DIR="/nxcore"
        CONFIG_DIR="/nxconfig"

        local errors=()
        [[ -d "$NXCORE_DIR" ]] || errors+=("Core repository not found at /nxcore")
        [[ -d "$CONFIG_DIR" ]] || errors+=("Config repository not found at /nxconfig")
        [[ -d "$NXCORE_DIR/.git" ]] || errors+=("Core repository at /nxcore is not a git repository")
        [[ -d "$CONFIG_DIR/.git" ]] || errors+=("Config repository at /nxconfig is not a git repository")
        [[ -f "$NXCORE_DIR/flake.nix" ]] || errors+=("Core repository missing flake.nix")
        [[ -d "$CONFIG_DIR/profiles" ]] || errors+=("Config repository missing profiles directory")

        if [[ ${#errors[@]} -gt 0 && "$REQUIRED" == "true" ]]; then
            echo -e "${RED}Error: Live disk setup incomplete for operation '${WHITE}$OPERATION${RED}'${RESET}" >&2
            echo "" >&2
            printf "  ${WHITE}- ${RED}%s${RESET}\n" "${errors[@]}" >&2
            echo "" >&2
            echo -e "${RED}Expected live disk setup:${RESET}" >&2
            echo -e "  ${WHITE}git clone <core-repo> /nxcore${RESET}" >&2
            echo -e "  ${WHITE}git clone <config-repo> /nxconfig${RESET}" >&2
            echo "" >&2
            exit 1
        fi
    else
        NXCORE_DIR="$HOME/.config/nx/nxcore"
        CONFIG_DIR="$HOME/.config/nx/nxconfig"

        if [[ ! -d "$CONFIG_DIR" && "$REQUIRED" == "true" ]]; then
            echo -e "${RED}Error: Config directory not found!${RESET}" >&2
            echo "" >&2
            echo -e "Expected path: ${WHITE}$CONFIG_DIR${RESET}" >&2
            echo -e "Operation '${WHITE}$OPERATION${RESET}' requires access to config data." >&2
            exit 1
        fi

        if [[ ! -d "$CONFIG_DIR" ]]; then
            CONFIG_DIR=""
        fi
    fi

    export NXCORE_DIR CONFIG_DIR
}

check_config_directory_optional() {
    local OPERATION="$1"
    local CONTEXT="${2:-deployment}"
    check_config_directory "$OPERATION" "$CONTEXT" "false"
}

deployment_script_setup() {
    local script_name="$1"

    if [[ -z "${NX_INSTALL_PATH:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    else
        SCRIPT_DIR="${NX_INSTALL_PATH}/scripts/deployment"
    fi
    cd "${NXCORE_DIR:-$HOME/.config/nx/nxcore}"

    if [[ "$UID" == 0 ]]; then
        echo -e "${RED}Do NOT run as root!${RESET}" >&2
        exit 1
    fi

    perm=$(ls -ld "$PWD" | awk '{print $1}')
    owner=$(ls -ld "$PWD" | awk '{print $3}')

    if [[ ! -d $PWD || $perm != drwx------* || $owner != "$USER" ]]; then
        echo -e "${RED}Permissions of enclosing configuration directory are too open!${RESET}" >&2
        exit 1
    fi

    check_config_directory "$script_name" "deployment"

    export SCRIPT_DIR
}

parse_common_deployment_args() {
    PROFILE_PATH="$(retrieve_active_profile_path)"
    EXTRA_ARGS=("--override-input" "config" "path:$CONFIG_DIR" "--override-input" "profile" "path:$PROFILE_PATH")
    ALLOW_DIRTY_GIT=false
    SKIP_VERIFICATION=false

    echo -e "${CYAN}Active branches:${RESET}"
    echo -e "  ${WHITE}nxcore:${RESET} ${YELLOW}$(git branch --show-current)${RESET}"
    if [[ -n "${CONFIG_DIR:-}" ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
        echo -e "  ${WHITE}nxconfig:${RESET} ${YELLOW}$(cd "$CONFIG_DIR" && git branch --show-current)${RESET}"
    fi
    echo

    while [[ $# -gt 0 ]]; do
        case "${1:-}" in
            --offline)
                EXTRA_ARGS+=("--option" "substitute" "false")
                shift
                ;;
            --show-trace)
                EXTRA_ARGS+=("--show-trace")
                shift
                ;;
            --allow-dirty-git)
                ALLOW_DIRTY_GIT=true
                shift
                ;;
            --skip-verification)
                SKIP_VERIFICATION=true
                shift
                ;;
            -*|--*)
                echo -e "${RED}Unknown option ${WHITE}${1:-}${RESET}"
                exit 1
                ;;
            *)
                echo -e "${RED}Unknown argument ${WHITE}${1:-}${RESET}"
                exit 1
                ;;
        esac
    done

    export EXTRA_ARGS ALLOW_DIRTY_GIT SKIP_VERIFICATION PROFILE_PATH
}

parse_build_deployment_args() {
    PROFILE_PATH="$(retrieve_active_profile_path)"
    EXTRA_ARGS=("--override-input" "config" "path:$CONFIG_DIR" "--override-input" "profile" "path:$PROFILE_PATH")
    TIMEOUT=2400
    DRY_RUN=""
    BUILD_DIFF=false
    SKIP_VERIFICATION=false

    echo -e "${CYAN}Active branches:${RESET}"
    echo -e "  ${WHITE}nxcore:${RESET} ${YELLOW}$(git branch --show-current)${RESET}"
    if [[ -n "${CONFIG_DIR:-}" ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
        echo -e "  ${WHITE}nxconfig:${RESET} ${YELLOW}$(cd "$CONFIG_DIR" && git branch --show-current)${RESET}"
    fi
    echo

    while [[ $# -gt 0 ]]; do
        case "${1:-}" in
            --offline)
                EXTRA_ARGS+=("--option" "substitute" "false")
                shift
                ;;
            --timeout)
                TIMEOUT="${2:-2400}"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="--dry-run"
                shift
                ;;
            --diff)
                BUILD_DIFF=true
                shift
                ;;
            --skip-verification)
                SKIP_VERIFICATION=true
                shift
                ;;
            --help|-h)
                echo "build: Test build configuration without deploying"
                echo ""
                echo "Options:"
                echo "  --timeout <seconds>   Set timeout (default: 2400)"
                echo "  --dry-run            Test build without actual building"
                echo "  --offline            Build without network access"
                echo "  --diff               Compare built config with current active system"
                echo "  --skip-verification  Skip commit signature verification"
                exit 0
                ;;
            -*|--*)
                echo -e "${RED}Unknown option ${WHITE}${1:-}${RESET}"
                exit 1
                ;;
            *)
                echo -e "${RED}Unknown argument ${WHITE}${1:-}${RESET}"
                exit 1
                ;;
        esac
    done

    export EXTRA_ARGS TIMEOUT DRY_RUN PROFILE_PATH BUILD_DIFF SKIP_VERIFICATION
}

ensure_nixos_only() {
    local command_name="$1"
    if [[ ! -e /etc/NIXOS ]]; then
        echo -e "${RED}Command '${WHITE}$command_name${RED}' only available on NixOS${RESET}" >&2
        exit 1
    fi
}

ensure_standalone_only() {
    local command_name="$1"
    if [[ -e /etc/NIXOS ]]; then
        echo -e "${RED}Command '${WHITE}$command_name${RED}' only available on Standalone${RESET}" >&2
        exit 1
    fi
}

ensure_darwin_only() {
    local command_name="$1"
    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo -e "${RED}Command '${WHITE}$command_name${RED}' only available on Darwin (macOS)${RESET}" >&2
        exit 1
    fi
}

parse_minimal_deployment_args() {
    EXTRA_ARGS=()
    ALLOW_DIRTY_GIT=false

    while [[ $# -gt 0 ]]; do
        case "${1:-}" in
            --allow-dirty-git)
                ALLOW_DIRTY_GIT=true
                shift
                ;;
            -*|--*)
                echo -e "${RED}Unknown option ${WHITE}${1:-}${RESET}"
                exit 1
                ;;
            *)
                echo -e "${RED}Unknown argument ${WHITE}${1:-}${RESET}"
                exit 1
                ;;
        esac
    done

    export EXTRA_ARGS ALLOW_DIRTY_GIT
}

simple_deployment_script_setup() {
    local script_name="$1"

    if [[ -z "${NX_INSTALL_PATH:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    else
        SCRIPT_DIR="${NX_INSTALL_PATH}/scripts/deployment"
    fi
    cd "${NXCORE_DIR:-$HOME/.config/nx/nxcore}"

    if [[ "$UID" == 0 ]]; then
        echo -e "${RED}Do NOT run as root!${RESET}" >&2
        exit 1
    fi

    perm=$(ls -ld "$PWD" | awk '{print $1}')
    owner=$(ls -ld "$PWD" | awk '{print $3}')

    if [[ ! -d $PWD || $perm != drwx------* || $owner != "$USER" ]]; then
        echo -e "${RED}Permissions of enclosing configuration directory are too open!${RESET}" >&2
        exit 1
    fi

    export SCRIPT_DIR
}

ensure_nix_path() {
  if ! command -v nix >/dev/null 2>&1; then
    export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
    if ! command -v nix >/dev/null 2>&1; then
      echo -e "${RED}Error: Nix not found in PATH even after adding standard locations${RESET}" >&2
      echo "Please ensure Nix was installed correctly or run in a new shell" >&2
      exit 1
    fi
  fi
}

if [[ "${BOOTSTRAP_NEEDS_NIX:-false}" == "true" ]]; then
  ensure_nix_path
fi

check_git_worktrees_clean() {
    local main_dirty=false
    local config_dirty=false

    if [[ "$(git status --porcelain)" != "" ]]; then
        main_dirty=true
    fi

    if [[ -n "${CONFIG_DIR:-}" ]] && [[ -d "$CONFIG_DIR" ]]; then
        if [[ "$(cd "$CONFIG_DIR" && git status --porcelain 2>/dev/null)" != "" ]]; then
            config_dirty=true
        fi
    fi

    if [[ "$main_dirty" == true ]] || [[ "$config_dirty" == true ]]; then
        echo -e "${YELLOW}!!! Git worktree(s) are dirty!${RESET}" >&2
        echo >&2

        if [[ "$main_dirty" == true ]]; then
            echo -e "${RED}Main repository (.config/nx/nxcore):${RESET}" >&2
            git status --porcelain >&2
            echo >&2
        fi

        if [[ "$config_dirty" == true ]]; then
            echo -e "${RED}Config repository (.config/nx/nxconfig):${RESET}" >&2
            (cd "$CONFIG_DIR" && git status --porcelain) >&2
            echo >&2
        fi

        if [[ "${ALLOW_DIRTY_GIT:-false}" == "true" ]]; then
            echo -e "${YELLOW}WARNING: Proceeding with dirty git worktree(s) due to --allow-dirty-git flag${RESET}" >&2
            echo >&2
        else
            exit 1
        fi
    fi
}

verify_commits() {
    if [[ "${SKIP_VERIFICATION:-false}" == "true" ]]; then
        echo -e "${MAGENTA}Skipping commit verification due to --skip-verification flag${RESET}" >&2
        echo
        return 0
    fi

    if [[ -z "${COMMIT_VERIFICATION_NXCORE:-}" ]]; then
        load_nx_config
    fi

    local verification_failed=false

    if [[ -n "${NXCORE_DIR:-}" && -d "$NXCORE_DIR" ]]; then
        verify_repo_commits "$NXCORE_DIR" "nxcore" "$COMMIT_VERIFICATION_NXCORE" || verification_failed=true
    fi

    if [[ -n "${CONFIG_DIR:-}" && -d "$CONFIG_DIR" ]]; then
        verify_repo_commits "$CONFIG_DIR" "nxconfig" "$COMMIT_VERIFICATION_NXCONFIG" || verification_failed=true
    fi

    if [[ "$verification_failed" == true ]]; then
        echo >&2
        echo -e "${RED}Commit verification failed. Use ${WHITE}--skip-verification${RED} to override.${RESET}" >&2
        return 1
    fi

    return 0
}

verify_repo_commits() {
    local repo_path="$1"
    local repo_name="$2"
    local mode="$3"

    case "$mode" in
        "none")
            echo -e "${GRAY}Skipping commit verification for $repo_name (mode: none)${RESET}" >&2
            return 0
            ;;
        "last")
            echo -e "${CYAN}Verifying last commit in $repo_name...${RESET}" >&2
            verify_commit_range "$repo_path" "$repo_name" "HEAD~1..HEAD"
            ;;
        "all")
            echo -e "${CYAN}Verifying all commits in $repo_name...${RESET}" >&2
            verify_all_repo_commits "$repo_path" "$repo_name"
            ;;
        *)
            echo -e "${RED}Unknown verification mode for $repo_name: $mode${RESET}" >&2
            return 1
            ;;
    esac
}

verify_commit_range() {
    local repo_path="$1"
    local repo_name="$2"
    local range="$3"

    (cd "$repo_path" || return 1

    local commits=$(git rev-list "$range" 2>/dev/null || echo "")
    if [[ -z "$commits" ]]; then
        echo -e "${GRAY}No commits to verify in $repo_name range $range${RESET}" >&2
        return 0
    fi

    local failed_commits=()
    for commit in $commits; do
        if ! git verify-commit "$commit" 2>&1 | grep -q "Good signature"; then
            failed_commits+=("$commit")
        fi
    done

    if [[ ${#failed_commits[@]} -gt 0 ]]; then
        echo
        echo -e "${RED}Commits without good signatures found in $repo_name:${RESET}" >&2
        for commit in "${failed_commits[@]}"; do
            echo -e "  ${WHITE}- $(git log --oneline -1 "$commit")${RESET}" >&2
        done
        echo
        return 1
    fi

    local num_commits=$(echo "$commits" | wc -l | tr -d ' ')
    if [[ "$num_commits" -eq 1 ]]; then
        echo -e "${BLUE}Commit verification: ${GREEN}Last commit verified in $repo_name${RESET}" >&2
    else
        echo -e "${BLUE}Commit verification: ${GREEN}$num_commits commits verified in $repo_name${RESET}" >&2
    fi
    echo
    return 0
    )
}

verify_all_repo_commits() {
    local repo_path="$1"
    local repo_name="$2"

    (cd "$repo_path" || return 1

    local all_commits=$(git rev-list HEAD 2>/dev/null || echo "")
    if [[ -z "$all_commits" ]]; then
        echo -e "${GRAY}No commits to verify in $repo_name${RESET}" >&2
        return 0
    fi

    local total_commits=$(echo "$all_commits" | wc -l | tr -d ' ')
    local failed_commits=()
    local count=0

    echo -e "${WHITE}Checking $total_commits commits in $repo_name...${RESET}" >&2

    for commit in $all_commits; do
        ((count++))
        if ! git verify-commit "$commit" 2>&1 | grep -q "Good signature"; then
            failed_commits+=("$commit")
        fi

        if [[ $((count % 50)) -eq 0 ]]; then
            echo -e "${GRAY}Verified $count/$total_commits commits...${RESET}" >&2
        fi
    done

    if [[ ${#failed_commits[@]} -gt 0 ]]; then
        echo
        echo -e "${RED}Found ${#failed_commits[@]} commits without good signatures in $repo_name${RESET}" >&2

        local show_count=$((${#failed_commits[@]} > 5 ? 5 : ${#failed_commits[@]}))
        for ((i=0; i<show_count; i++)); do
            echo -e "  ${WHITE}- $(git log --oneline -1 "${failed_commits[i]}")${RESET}" >&2
        done
        if [[ ${#failed_commits[@]} -gt 5 ]]; then
            echo -e "  ${GRAY}... and $((${#failed_commits[@]} - 5)) more${RESET}" >&2
        fi
        echo
        return 1
    fi

    echo -e "${BLUE}Commit verification: ${GREEN}All $total_commits commits verified in $repo_name${RESET}" >&2
    echo
    return 0
    )
}

parse_git_args() {
    ONLY_CORE=false
    ONLY_CONFIG=false
    EXTRA_ARGS=()

    while [[ $# -gt 0 ]]; do
        case "${1:-}" in
            --only-core)
                ONLY_CORE=true
                shift
                ;;
            --only-config)
                ONLY_CONFIG=true
                shift
                ;;
            *)
                EXTRA_ARGS+=("$1")
                shift
                ;;
        esac
    done

    if [[ "$ONLY_CORE" == true && "$ONLY_CONFIG" == true ]]; then
        echo -e "${RED}Error: Cannot specify both ${WHITE}--only-core${RED} and ${WHITE}--only-config${RED} at the same time${RESET}" >&2
        exit 1
    fi

    export ONLY_CORE ONLY_CONFIG EXTRA_ARGS
}

get_latest_commit_timestamp() {
    local repo_dir="$1"
    if [[ -d "$repo_dir/.git" ]]; then
        cd "$repo_dir" && git log -1 --pretty=format:"%ct" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

export_nixos_label() {
    local use_dir="$CONFIG_DIR"

    if [[ -n "${CONFIG_DIR:-}" && -n "${NXCORE_DIR:-}" && -d "$CONFIG_DIR/.git" && -d "$NXCORE_DIR/.git" ]]; then
        local config_timestamp=$(get_latest_commit_timestamp "$CONFIG_DIR")
        local core_timestamp=$(get_latest_commit_timestamp "$NXCORE_DIR")

        if [[ "$core_timestamp" -gt "$config_timestamp" ]]; then
            use_dir="$NXCORE_DIR"
        fi
    elif [[ -n "${NXCORE_DIR:-}" && -d "$NXCORE_DIR/.git" ]]; then
        use_dir="$NXCORE_DIR"
    fi

    commit_msg=$(cd "$use_dir" && git log -1 --pretty=format:"%s" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g' | awk '{if(length($0)>25) print substr($0,1,24)"-"; else print $0}' | sed 's/--$/-/')
    export NIXOS_LABEL="$(cd "$use_dir" && git log -1 --pretty=format:"$(git branch --show-current).%cd.${commit_msg}" --date=format:'%d-%m-%y.%H:%M' | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9:_.-]//g')"
}

detect_system_architecture() {
    local uname_system="$(uname -s)"
    local uname_machine="$(uname -m)"

    case "$uname_system" in
        Linux)
            case "$uname_machine" in
                x86_64)
                    echo "x86_64-linux"
                    ;;
                aarch64|arm64)
                    echo "aarch64-linux"
                    ;;
                *)
                    echo -e "${RED}Error: Unsupported Linux architecture: ${WHITE}$uname_machine${RESET}" >&2
                    exit 1
                    ;;
            esac
            ;;
        Darwin)
            case "$uname_machine" in
                x86_64)
                    echo "x86_64-darwin"
                    ;;
                arm64)
                    echo "aarch64-darwin"
                    ;;
                *)
                    echo -e "${RED}Error: Unsupported Darwin architecture: ${WHITE}$uname_machine${RESET}" >&2
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}Error: Unsupported system: ${WHITE}$uname_system${RESET}" >&2
            exit 1
            ;;
    esac
}

construct_profile_name() {
    local base_profile="$1"
    local architecture="$(detect_system_architecture)"
    echo "${base_profile}--${architecture}"
}

retrieve_active_profile() {
    local base_profile
    local target_profile
    if [[ -e .nx-profile.conf ]]; then
        base_profile="$(cat .nx-profile.conf)"
        echo -e "Found base profile in ${WHITE}$PWD/.nx-profile.conf${RESET} file: ${WHITE}$base_profile${RESET}" >&2
    else
        if [[ -e /etc/nixos ]]; then
            base_profile="$HOSTNAME"
        else
            base_profile="$USER"
        fi
    fi

    target_profile="$(construct_profile_name "$base_profile")"
    local arch="${target_profile#$base_profile--}"
    echo -e "${GREEN}Selected profile: ${YELLOW}$base_profile ${RED}(${arch})${RESET}\n" >&2
    echo "$target_profile"
}

retrieve_active_profile_path() {
    local base_profile
    if [[ -e .nx-profile.conf ]]; then
        base_profile="$(cat .nx-profile.conf)"
    else
        if [[ -e /etc/nixos ]]; then
            base_profile="$HOSTNAME"
        else
            base_profile="$USER"
        fi
    fi

    local profile_path
    if [[ -e /etc/NIXOS ]]; then
        profile_path="$CONFIG_DIR/profiles/nixos/$base_profile"
    else
        profile_path="$CONFIG_DIR/profiles/home-standalone/$base_profile"
    fi
    echo -e "${GREEN}Using profile path: ${RED}$profile_path${RESET}\n" >&2
    echo "$profile_path"
}

copy_config_to_target() {
    local USERNAME="$1"
    local TARGET_HOME="$2"
    local USER_ID="$3"
    local GROUP_ID="$4"

    if [[ -z "$CONFIG_DIR" ]]; then
        echo -e "${RED}Error: CONFIG_DIR not set. Call check_config_directory first.${RESET}" >&2
        exit 1
    fi

    local TARGET_CONFIG="/mnt$TARGET_HOME/.config/nx/nxconfig"

    echo -e "${WHITE}Copying config to target system...${RESET}"
    mkdir -p "/mnt$TARGET_HOME/.config/nx"
    cp -R --verbose -T "$CONFIG_DIR" "$TARGET_CONFIG"
    chown -R "$USER_ID:$GROUP_ID" "$TARGET_CONFIG"
    echo -e "${GREEN}Config copied to ${WHITE}$TARGET_CONFIG${GREEN}.${RESET}"
}

configure_target_git_remotes() {
    local TARGET_HOME="$1"
    local USER_ID="$2"
    local GROUP_ID="$3"

    if [[ -z "$CONFIG_DIR" ]]; then
        echo -e "${RED}Error: CONFIG_DIR not set. Call check_config_directory first.${RESET}" >&2
        exit 1
    fi

    local PROFILE_PATH="$(retrieve_active_profile_path)"

    local TARGET_CORE="/mnt$TARGET_HOME/.config/nx/nxcore"
    local TARGET_CONFIG="/mnt$TARGET_HOME/.config/nx/nxconfig"

    local CORE_INSTALL_URL
    local CONFIG_INSTALL_URL

    CORE_INSTALL_URL="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" ".#variables.coreRepoInstallUrl" 2>/dev/null || echo "null")"
    if [[ "$CORE_INSTALL_URL" == "null" || "$CORE_INSTALL_URL" == "\"null\"" ]]; then
        CORE_INSTALL_URL="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" ".#variables.coreRepoIsoUrl" 2>/dev/null)"
    fi
    CORE_INSTALL_URL="${CORE_INSTALL_URL//\"/}"

    CONFIG_INSTALL_URL="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" ".#variables.configRepoInstallUrl" 2>/dev/null || echo "null")"
    if [[ "$CONFIG_INSTALL_URL" == "null" || "$CONFIG_INSTALL_URL" == "\"null\"" ]]; then
        CONFIG_INSTALL_URL="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" ".#variables.configRepoIsoUrl" 2>/dev/null)"
    fi
    CONFIG_INSTALL_URL="${CONFIG_INSTALL_URL//\"/}"

    echo -e "${WHITE}Configuring git remotes for target system...${RESET}"

    if [[ -d "$TARGET_CORE/.git" && -n "$CORE_INSTALL_URL" ]]; then
        echo -e "Setting core repository remote to: ${WHITE}$CORE_INSTALL_URL${RESET}"
        cd "$TARGET_CORE"
        if git remote get-url origin >/dev/null 2>&1; then
            git remote set-url origin "$CORE_INSTALL_URL"
        else
            git remote add origin "$CORE_INSTALL_URL"
        fi
        chown -R "$USER_ID:$GROUP_ID" "$TARGET_CORE/.git"
    fi

    if [[ -d "$TARGET_CONFIG/.git" && -n "$CONFIG_INSTALL_URL" ]]; then
        echo -e "Setting config repository remote to: ${WHITE}$CONFIG_INSTALL_URL${RESET}"
        cd "$TARGET_CONFIG"
        if git remote get-url origin >/dev/null 2>&1; then
            git remote set-url origin "$CONFIG_INSTALL_URL"
        else
            git remote add origin "$CONFIG_INSTALL_URL"
        fi
        chown -R "$USER_ID:$GROUP_ID" "$TARGET_CONFIG/.git"
    fi

    echo -e "${GREEN}Git remotes configured for target system.${RESET}"
}

setup_log_directory() {
    local log_dir="$1"
    local real_user="${SUDO_USER:-$USER}"
    local real_uid="${SUDO_UID:-$(id -u)}"
    local real_gid="${SUDO_GID:-$(id -g)}"

    mkdir -p "$log_dir"

    if [[ "$UID" == 0 && -n "${SUDO_USER:-}" ]]; then
        chown "$real_uid:$real_gid" "$log_dir"
        local parent_dir="$(dirname "$log_dir")"
        while [[ "$parent_dir" != "/" && "$parent_dir" != "." ]]; do
            if [[ "$(stat -c %u "$parent_dir")" == "0" ]]; then
                chown "$real_uid:$real_gid" "$parent_dir"
            fi
            parent_dir="$(dirname "$parent_dir")"
        done
    fi
}

rotate_logs() {
    local log_dir="$1"
    local max_logs="${2:-10}"

    if [[ ! -d "$log_dir" ]]; then
        return 0
    fi

    local logs=($(find "$log_dir" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | cut -d' ' -f2-))
    local log_count=${#logs[@]}

    if [[ $log_count -gt $max_logs ]]; then
        local to_remove=$((log_count - max_logs))
        for ((i=0; i<to_remove; i++)); do
            rm -f "${logs[i]}" 2>/dev/null || true
        done
    fi
}

create_log_filename() {
    local log_dir="$1"
    local prefix="$2"
    local timestamp="$(date '+%Y%m%d_%H%M%S')"
    echo "$log_dir/${prefix}_${timestamp}.log"
}

create_log_file() {
    local log_file="$1"
    local real_user="${SUDO_USER:-$USER}"
    local real_uid="${SUDO_UID:-$(id -u)}"
    local real_gid="${SUDO_GID:-$(id -g)}"

    touch "$log_file"

    if [[ "$UID" == 0 && -n "${SUDO_USER:-}" ]]; then
        chown "$real_uid:$real_gid" "$log_file"
    fi
}

setup_deployment_lock() {
    local command_name="$1"
    local lock_dir="/tmp/.nx-deployment-lock"

    if [[ -d "$lock_dir" ]]; then
        echo
        echo -e "${RED}Error: Another deployment command is already running${RESET}" >&2
        echo
        echo -e "${YELLOW}If you're sure no deployment is running, remove it with:${RESET}" >&2
        echo -e "${WHITE}  rmdir '$lock_dir'${RESET}" >&2
        exit 1
    fi

    if ! mkdir "$lock_dir" 2>/dev/null; then
        echo -e "${RED}Error: Failed to create deployment lock directory${RESET}" >&2
        exit 1
    fi

    echo "$$:$command_name:$(date +%s)" > "$lock_dir/info"

    trap 'cleanup_deployment_lock; exit 130' INT
    trap 'cleanup_deployment_lock; exit 143' TERM
    trap 'cleanup_deployment_lock' EXIT
}

cleanup_deployment_lock() {
    local lock_dir="/tmp/.nx-deployment-lock"
    if [[ -d "$lock_dir" ]]; then
        rm -rf "$lock_dir" 2>/dev/null || true
    fi
}

check_nix_daemon_activity() {
    local build_processes
    build_processes=$(ps ax -o stat,command | tail -n +2 | grep "nix-daemon" | grep -v -- "--daemon" | grep -v grep | awk '$1 ~ /^(R|Rs|Rl|Ssl|S\+)$/' | wc -l) || build_processes=0

    if [[ "$build_processes" -gt 0 ]]; then
        echo
        echo -en "${GREEN}Nix-daemon is active, continue anyway? ${RESET}[Y/n]: " >&2
        read -r response
        case "$response" in
            [nN]|[nN][oO])
                echo
                echo -e "${RED}Aborted due to nix daemon activity${RESET}" >&2
                exit 1
                ;;
            *)
                return 0
                ;;
        esac
    fi

    return 0
}

check_nix_tool_activity() {
    local nix_tool_processes
    nix_tool_processes=$(ps ax -o stat,command | tail -n +2 | grep -E "nix (build|eval|flake|gc)" | grep -v grep | awk '$1 ~ /^(R|Rs|Rl|S\+)$/' | wc -l) || nix_tool_processes=0

    if [[ "$nix_tool_processes" -gt 0 ]]; then
        echo
        echo -e "${RED}Warning: Nix tools appears to be active ($nix_tool_processes active processes)${RESET}" >&2
        echo -e "${YELLOW}Running concurrent actions may cause issues.${RESET}" >&2
        echo
        echo -en "${WHITE}Do you want to continue anyway? ${RESET}[y/N]: " >&2
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            *)
                echo
                echo -e "${RED}Aborted due to nix tool activity${RESET}" >&2
                exit 1
                ;;
        esac
    fi

    return 0
}

check_nh_activity() {
    local nh_processes
    nh_processes=$(ps ax -o stat,command | tail -n +2 | grep " nh " | grep -v grep | awk '$1 ~ /^(R|Rs|Rl|S\+)$/' | wc -l) || nh_processes=0

    if [[ "$nh_processes" -gt 0 ]]; then
        echo
        echo -e "${RED}Warning: nh tool appears to be active ($nh_processes active processes)${RESET}" >&2
        echo -e "${YELLOW}Running concurrent actions may cause issues.${RESET}" >&2
        echo
        echo -en "${WHITE}Do you want to continue anyway? ${RESET}[y/N]: " >&2
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            *)
                echo
                echo -e "${RED}Aborted due to nh tool activity${RESET}" >&2
                exit 1
                ;;
        esac
    fi

    return 0
}

load_nx_config() {
    if [[ "${NX_CONFIG_LOADED:-0}" -eq 1 ]]; then
        return
    fi

    local config_file=""
    local config_json=""

    if [[ -f "/etc/nx/config.json" ]]; then
        config_file="/etc/nx/config.json"
        echo -e "${GREEN}Using system config: ${WHITE}/etc/nx/config.json${RESET}" >&2
        config_json=$(cat "$config_file")
    elif [[ -f "$HOME/.config/nx/config.json" ]]; then
        config_file="$HOME/.config/nx/config.json"
        echo -e "${GREEN}Using user config: ${WHITE}$HOME/.config/nx/config.json${RESET}" >&2
        config_json=$(cat "$config_file")
    else
        echo -e "${YELLOW}No nx config found, using defaults${RESET}" >&2
        config_json=""
    fi
    echo

    NX_CONFIG_LOADED=1
    COMMIT_VERIFICATION_NXCORE=$(get_config_value "security.commitVerification.nxcore" "$config_json")
    COMMIT_VERIFICATION_NXCONFIG=$(get_config_value "security.commitVerification.nxconfig" "$config_json")

    export NX_CONFIG_LOADED COMMIT_VERIFICATION_NXCORE COMMIT_VERIFICATION_NXCONFIG
}

check_brew_activity() {
    local brew_processes
    brew_processes=$(ps ax -o stat,command | tail -n +2 | grep "/opt/homebrew/Library/Homebrew/brew.sh" | grep -v grep | awk '$1 ~ /^(R|Rs|Rl|S\+)$/' | wc -l) || brew_processes=0

    if [[ "$brew_processes" -gt 0 ]]; then
        echo
        echo -e "${RED}Warning: Homebrew appears to be running ($brew_processes active processes)${RESET}" >&2
        echo -e "${YELLOW}Running concurrent brew operations may cause issues.${RESET}" >&2
        echo
        echo -en "${WHITE}Do you want to continue anyway? ${RESET}[y/N]: " >&2
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            *)
                echo
                echo -e "${RED}Aborted due to active brew processes${RESET}" >&2
                exit 1
                ;;
        esac
    fi

    return 0
}

check_deployment_conflicts() {
    local command_name="$1"
    setup_deployment_lock "$command_name"

    check_nix_daemon_activity
    check_nix_tool_activity
    check_nh_activity

    if [[ "$command_name" == "brew" ]]; then
        check_brew_activity
    fi
}
