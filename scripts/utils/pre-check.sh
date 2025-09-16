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
    
    source "$SCRIPT_DIR/../utils/pre-check.sh"
    check_config_directory "$script_name" "deployment"
    
    export SCRIPT_DIR
}

parse_common_deployment_args() {
    PROFILE_PATH="$(retrieve_active_profile_path)"
    EXTRA_ARGS=("--override-input" "config" "path:$CONFIG_DIR" "--override-input" "profile" "path:$PROFILE_PATH")
    ALLOW_DIRTY_GIT=false
    
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
    
    export EXTRA_ARGS ALLOW_DIRTY_GIT PROFILE_PATH
}

parse_build_deployment_args() {
    PROFILE_PATH="$(retrieve_active_profile_path)"
    EXTRA_ARGS=("--override-input" "config" "path:$CONFIG_DIR" "--override-input" "profile" "path:$PROFILE_PATH")
    TIMEOUT=600
    DRY_RUN=""
    
    while [[ $# -gt 0 ]]; do
        case "${1:-}" in
            --offline)
                EXTRA_ARGS+=("--option" "substitute" "false")
                shift
                ;;
            --timeout)
                TIMEOUT="${2:-3600}"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="--dry-run"
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
    
    export EXTRA_ARGS TIMEOUT DRY_RUN PROFILE_PATH
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
            echo -e "${WHITE}Main repository (.config/nx/nxcore):${RESET}" >&2
            git status --porcelain >&2
            echo >&2
        fi
        
        if [[ "$config_dirty" == true ]]; then
            echo -e "${WHITE}Config repository (.config/nx/nxconfig):${RESET}" >&2
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

export_nixos_label() {
    commit_msg=$(cd "$CONFIG_DIR" && git log -1 --pretty=format:"%s" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g' | awk '{if(length($0)>25) print substr($0,1,24)"-"; else print $0}' | sed 's/--$/-/')
    export NIXOS_LABEL="$(cd "$CONFIG_DIR" && git log -1 --pretty=format:"$(git branch --show-current).%cd.${commit_msg}" --date=format:'%d-%m-%y.%H:%M' | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9:_.-]//g')"
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
