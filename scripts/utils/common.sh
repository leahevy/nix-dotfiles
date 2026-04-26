#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/defs.sh"

print_info() {
  echo -e "${WHITE}" "$@" "${RESET}"
}

print_success() {
  echo -e "${GREEN}" "$@" "${RESET}"
}

print_error() {
  echo -e "${RED}" "$@" "${RESET}"
}

strip_html() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/<[^>]*>//g'
}

notify_user() {
    local title message urgency icon
    title="${1:-}"
    message="${2:-}"
    urgency="${3:-}"
    icon="${4:-}"

    if [[ "$title" == "" || "$message" == "" ]]; then
      print_error "Invalid usage of notify_user deployment function: title or message missing!"
      return
    fi

    if [[ "$(uname -s)" == "Linux" ]]; then
      if systemctl --user cat nx-user-notify-monitor >/dev/null 2>&1; then
        logger -p "user.${urgency}" -t nx-user-notify "$title|$icon: $message" || true
      else
        if command -v notify-send >/dev/null 2>&1; then
          local args
          args=("$title" "$message")
          if [[ "$icon" != "" ]]; then
            args+=("--icon" "$icon")
          fi
          if [[ "$urgency" != "" ]]; then
            args+=("--urgency")
            if [[ "$urgency" == "info" ]]; then
              args+=("normal")
            elif [[ "$urgency" == "error" ]]; then
              args+=("critical")
            else
              args+=("low")
            fi
          fi
          notify-send "${args[@]}" || true
        fi
      fi
    elif [[ "$(uname -s)" == "Darwin" ]]; then
      local clean_message
      clean_message="$(strip_html "$message")"
      title="$title" message="$clean_message" /usr/bin/osascript -e 'display notification (system attribute "message") with title (system attribute "title")' || true
    fi
}

notify_success() {
  command="${1:-}"

  if [[ "$command" != "" ]]; then
    notify_user "Nix Deployment Command" "Successfully completed <b>$command</b>" info "$SUCCESS_ICON"
  fi
}

notify_error() {
  command="${1:-}"

  if [[ "$command" != "" ]]; then
    notify_user "Nix Deployment Command" "<b>$command</b> failed!" error "$ERROR_ICON"
  fi
}

is_modules_only_input() {
    local input_name="$1"
    for entry in "${MODULES_ONLY_INPUTS[@]}"; do
        [[ "$input_name" == "$entry" ]] && return 0
    done
    return 1
}

module_file_path() {
    local base_path="$1"
    local input_name="$2"
    local group_name="$3"
    local module_name="$4"
    if is_modules_only_input "$input_name"; then
        echo "$base_path/$group_name/$module_name.nix"
    else
        echo "$base_path/modules/$group_name/$module_name.nix"
    fi
}

get_nx_default() {
    local key="$1"
    case "$key" in
        "security.commitVerification.nxcore")
            echo "all"
            ;;
        "security.commitVerification.nxconfig")
            echo "all"
            ;;
        "deploymentMode")
            echo "develop"
            ;;
        *)
            echo ""
            ;;
    esac
}

get_config_value() {
    local key="$1"
    local config_json="$2"
    local default_value
    default_value="$(get_nx_default "$key")"

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

    if [[ "${WORKFLOW_RUN:-}" == "1" && -n "${NXCORE_DIR:-}" && -n "${CONFIG_DIR:-}" ]]; then
        export NXCORE_DIR CONFIG_DIR
        return
    fi

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

        if [[ ! -d "$NXCORE_DIR" ]]; then
            if [[ "${NX_DEPLOYMENT_MODE:-develop}" == "develop" && "$REQUIRED" == "true" ]]; then
                echo -e "${RED}Error: Core directory not found (required in develop mode)!${RESET}" >&2
                exit 1
            fi
            NXCORE_DIR=""
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
    cd "${CONFIG_DIR:-$HOME/.config/nx/nxconfig}" || exit 1

    if [[ "$UID" == 0 ]]; then
        echo -e "${RED}Do NOT run as root!${RESET}" >&2
        exit 1
    fi

    # shellcheck disable=SC2012
    perm=$(ls -ld "$PWD" | awk '{print $1}')
    # shellcheck disable=SC2012
    owner=$(ls -ld "$PWD" | awk '{print $3}')

    if [[ ! -d $PWD || $perm != drwx------* || $owner != "$USER" ]]; then
        echo -e "${RED}Permissions of enclosing configuration directory are too open!${RESET}" >&2
        exit 1
    fi

    check_config_directory "$script_name" "deployment"
    load_nx_config

    if [[ "${NX_DEPLOYMENT_MODE:-develop}" == "server" ]]; then
        echo -e "${YELLOW}WARNING: This machine is in server mode!${RESET}" >&2
        echo -en "${WHITE}Run manual deployment? ${RESET}[y/N]: " >&2
        read -r response
        case "$response" in
            [yY]|[yY][eE][sS]) ;;
            *) echo -e "${RED}Aborted${RESET}" >&2; exit 1 ;;
        esac
    fi

    export SCRIPT_DIR
}

parse_common_deployment_args() {
    if [[ "${NX_DEPLOYMENT_MODE:-develop}" == "develop" ]]; then
        EXTRA_ARGS=("--override-input" "core" "path:$NXCORE_DIR")
    else
        EXTRA_ARGS=()
    fi
    ALLOW_DIRTY_GIT=false
    SKIP_VERIFICATION=false

    local _branch_config _branch_core
    _branch_config="$(git branch --show-current)"
    _branch_core=""
    if [[ -n "${NXCORE_DIR:-}" ]] && [[ -d "$NXCORE_DIR/.git" ]]; then
        _branch_core="$(cd "$NXCORE_DIR" && git branch --show-current)"
    fi
    if [[ "$_branch_config" != "main" || ( -n "$_branch_core" && "$_branch_core" != "main" ) ]]; then
        echo -e "${CYAN}Active branches:${RESET}"
        echo -e "  ${WHITE}nxconfig:${RESET} ${YELLOW}${_branch_config}${RESET}"
        if [[ -n "$_branch_core" ]]; then
            echo -e "  ${WHITE}nxcore:${RESET} ${YELLOW}${_branch_core}${RESET}"
        fi
        echo
    fi

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
            --allow-ifd)
                EXTRA_ARGS+=("--option" "allow-import-from-derivation" "true")
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

    export EXTRA_ARGS ALLOW_DIRTY_GIT SKIP_VERIFICATION
}

parse_build_deployment_args() {
    if [[ "${NX_DEPLOYMENT_MODE:-develop}" == "develop" ]]; then
        EXTRA_ARGS=("--override-input" "core" "path:$NXCORE_DIR")
    else
        EXTRA_ARGS=()
    fi
    TIMEOUT=7200
    DRY_RUN=""
    BUILD_DIFF=false
    SKIP_VERIFICATION=false
    RAW_LOG=false
    BUILD_OVERRIDE_PROFILE=""
    BUILD_OVERRIDE_ARCH=""
    BUILD_FORCE_NIXOS=false
    BUILD_FORCE_STANDALONE=false
    SHOW_DERIVATION=false

    local _branch_config _branch_core
    _branch_config="$(git branch --show-current)"
    _branch_core=""
    if [[ -n "${NXCORE_DIR:-}" ]] && [[ -d "$NXCORE_DIR/.git" ]]; then
        _branch_core="$(cd "$NXCORE_DIR" && git branch --show-current)"
    fi
    if [[ "$_branch_config" != "main" || ( -n "$_branch_core" && "$_branch_core" != "main" ) ]]; then
        echo -e "${CYAN}Active branches:${RESET}"
        echo -e "  ${WHITE}nxconfig:${RESET} ${YELLOW}${_branch_config}${RESET}"
        if [[ -n "$_branch_core" ]]; then
            echo -e "  ${WHITE}nxcore:${RESET} ${YELLOW}${_branch_core}${RESET}"
        fi
        echo
    fi

    while [[ $# -gt 0 ]]; do
        case "${1:-}" in
            --offline)
                EXTRA_ARGS+=("--option" "substitute" "false")
                shift
                ;;
            --timeout)
                TIMEOUT="${2:-7200}"
                shift 2
                ;;
            --dry-run)
                DRY_RUN="--dry-run"
                shift
                ;;
            --show-trace)
                EXTRA_ARGS+=("--show-trace")
                shift
                ;;
            --diff)
                BUILD_DIFF=true
                shift
                ;;
            --show-derivation)
                SHOW_DERIVATION=true
                shift
                ;;
            --skip-verification)
                SKIP_VERIFICATION=true
                shift
                ;;
            --raw)
                RAW_LOG=true
                shift
                ;;
            --allow-ifd)
                EXTRA_ARGS+=("--option" "allow-import-from-derivation" "true")
                shift
                ;;
            --profile)
                [[ $# -lt 2 ]] && { echo -e "${RED}Error: --profile requires a profile name${RESET}" >&2; exit 1; }
                BUILD_OVERRIDE_PROFILE="$2"
                shift 2
                ;;
            --arch)
                [[ $# -lt 2 ]] && { echo -e "${RED}Error: --arch requires an architecture${RESET}" >&2; exit 1; }
                BUILD_OVERRIDE_ARCH="$2"
                shift 2
                ;;
            --nixos)
                BUILD_FORCE_NIXOS=true
                shift
                ;;
            --standalone)
                BUILD_FORCE_STANDALONE=true
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

    [[ "$BUILD_FORCE_NIXOS" == "true" && "$BUILD_FORCE_STANDALONE" == "true" ]] && {
        echo -e "${RED}Error: --nixos and --standalone cannot be used together${RESET}" >&2
        exit 1
    }

    [[ "$SHOW_DERIVATION" == "true" && "$BUILD_DIFF" == "true" ]] && {
        echo -e "${RED}Error: --show-derivation and --diff cannot be used together${RESET}" >&2
        exit 1
    }

    BUILD_HAS_OVERRIDE=false
    [[ -n "$BUILD_OVERRIDE_PROFILE" || -n "$BUILD_OVERRIDE_ARCH" || "$BUILD_FORCE_NIXOS" == "true" || "$BUILD_FORCE_STANDALONE" == "true" ]] && BUILD_HAS_OVERRIDE=true

    if [[ "$BUILD_HAS_OVERRIDE" == "true" && "$BUILD_DIFF" == "true" ]]; then
        echo -e "${RED}Error: --diff cannot be used together with --profile, --arch, --nixos, or --standalone${RESET}" >&2
        exit 1
    fi

    export EXTRA_ARGS TIMEOUT DRY_RUN BUILD_DIFF SKIP_VERIFICATION RAW_LOG SHOW_DERIVATION
    export BUILD_OVERRIDE_PROFILE BUILD_OVERRIDE_ARCH BUILD_FORCE_NIXOS BUILD_FORCE_STANDALONE BUILD_HAS_OVERRIDE
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

    export EXTRA_ARGS ALLOW_DIRTY_GIT
}

simple_deployment_script_setup() {
    local script_name="$1"

    if [[ -z "${NX_INSTALL_PATH:-}" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    else
        SCRIPT_DIR="${NX_INSTALL_PATH}/scripts/deployment"
    fi
    cd "${CONFIG_DIR:-$HOME/.config/nx/nxconfig}" || exit 1

    if [[ "$UID" == 0 ]]; then
        echo -e "${RED}Do NOT run as root!${RESET}" >&2
        exit 1
    fi

    # shellcheck disable=SC2012
    perm=$(ls -ld "$PWD" | awk '{print $1}')
    # shellcheck disable=SC2012
    owner=$(ls -ld "$PWD" | awk '{print $3}')

    if [[ ! -d $PWD || $perm != drwx------* || $owner != "$USER" ]]; then
        echo -e "${RED}Permissions of enclosing configuration directory are too open!${RESET}" >&2
        exit 1
    fi

    load_nx_config

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
    local config_dirty=false
    local core_dirty=false

    if [[ "$(git status --porcelain)" != "" ]]; then
        config_dirty=true
    fi

    if [[ -n "${NXCORE_DIR:-}" ]] && [[ -d "$NXCORE_DIR" ]]; then
        if [[ "$(cd "$NXCORE_DIR" && git status --porcelain 2>/dev/null)" != "" ]]; then
            core_dirty=true
        fi
    fi

    if [[ "$config_dirty" == true ]] || [[ "$core_dirty" == true ]]; then
        echo -e "${YELLOW}!!! Git worktree(s) are dirty!${RESET}" >&2
        echo >&2

        if [[ "$config_dirty" == true ]]; then
            echo -e "${RED}Config repository (.config/nx/nxconfig):${RESET}" >&2
            git status --porcelain >&2
            echo >&2
        fi

        if [[ "$core_dirty" == true ]]; then
            echo -e "${RED}Core repository (.config/nx/nxcore):${RESET}" >&2
            (cd "$NXCORE_DIR" && git status --porcelain) >&2
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

    local commits
    commits=$(git rev-list "$range" 2>/dev/null || echo "")
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
    return 0
    )
}

verify_all_repo_commits() {
    local repo_path="$1"
    local repo_name="$2"

    (cd "$repo_path" || return 1

    local all_commits
    all_commits=$(git rev-list HEAD 2>/dev/null || echo "")
    if [[ -z "$all_commits" ]]; then
        echo -e "${GRAY}No commits to verify in $repo_name${RESET}" >&2
        return 0
    fi

    local total_commits
    total_commits=$(echo "$all_commits" | wc -l | tr -d ' ')
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

    if [[ "${NX_DEPLOYMENT_MODE:-develop}" == "local" ]]; then
        ONLY_CONFIG=true
    fi

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

detect_system_architecture() {
    local uname_system
    uname_system="$(uname -s)"
    local uname_machine
    uname_machine="$(uname -m)"

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
    local target_arch="${2:-$(detect_system_architecture)}"
    local build_arch="${3:-$(detect_system_architecture)}"
    if [[ "$target_arch" == "$build_arch" ]]; then
        echo "${base_profile}--${target_arch}"
    else
        echo "${base_profile}--${target_arch}--${build_arch}"
    fi
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

    local default_profile
    if [[ -e /etc/nixos ]]; then
        default_profile="$HOSTNAME"
    else
        default_profile="$USER"
    fi

    target_profile="$(construct_profile_name "$base_profile")"
    local arch="${target_profile#"$base_profile"--}"
    if [[ "$base_profile" != "$default_profile" ]]; then
        echo -e "${GREEN}Selected profile: ${YELLOW}$base_profile ${RED}(${arch})${RESET}\n" >&2
        echo >&2
    fi
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

get_main_username() {
    local hostname
    hostname="${1:-"$(hostname)"}"
    local full_profile
    full_profile="$(construct_profile_name "$hostname")"

    if [[ -d "$CONFIG_DIR" ]]; then
        local username
        username="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$full_profile.config.nx.profile.host.mainUser.username" 2>/dev/null || echo "null")"
        if [[ -n "$username" && "$username" != "null" && "$username" != "\"null\"" ]]; then
            echo "${username//\"/}"
            return 0
        fi
    fi

    echo -e "${RED}Error: could not determine main user name!${RESET}" >&2
    exit 1
}

copy_config_to_target() {
    local TARGET_HOME="$1"
    local USER_ID="$2"
    local GROUP_ID="$3"

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

    local TARGET_CORE="/mnt$TARGET_HOME/.config/nx/nxcore"
    local TARGET_CONFIG="/mnt$TARGET_HOME/.config/nx/nxconfig"

    local CORE_INSTALL_URL
    local CONFIG_INSTALL_URL

    CORE_INSTALL_URL="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#variables.coreRepoInstallUrl" 2>/dev/null || echo "null")"
    if [[ "$CORE_INSTALL_URL" == "null" || "$CORE_INSTALL_URL" == "\"null\"" ]]; then
        CORE_INSTALL_URL="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#variables.coreRepoIsoUrl" 2>/dev/null)"
    fi
    CORE_INSTALL_URL="${CORE_INSTALL_URL//\"/}"

    CONFIG_INSTALL_URL="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#variables.configRepoInstallUrl" 2>/dev/null || echo "null")"
    if [[ "$CONFIG_INSTALL_URL" == "null" || "$CONFIG_INSTALL_URL" == "\"null\"" ]]; then
        CONFIG_INSTALL_URL="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#variables.configRepoIsoUrl" 2>/dev/null)"
    fi
    CONFIG_INSTALL_URL="${CONFIG_INSTALL_URL//\"/}"

    echo -e "${WHITE}Configuring git remotes for target system...${RESET}"

    if [[ -d "$TARGET_CORE/.git" && -n "$CORE_INSTALL_URL" ]]; then
        echo -e "Setting core repository remote to: ${WHITE}$CORE_INSTALL_URL${RESET}"
        cd "$TARGET_CORE" || return 1
        if git remote get-url origin >/dev/null 2>&1; then
            git remote set-url origin "$CORE_INSTALL_URL"
        else
            git remote add origin "$CORE_INSTALL_URL"
        fi
        chown -R "$USER_ID:$GROUP_ID" "$TARGET_CORE/.git"
    fi

    if [[ -d "$TARGET_CONFIG/.git" && -n "$CONFIG_INSTALL_URL" ]]; then
        echo -e "Setting config repository remote to: ${WHITE}$CONFIG_INSTALL_URL${RESET}"
        cd "$TARGET_CONFIG" || return 1
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
    local real_uid="${SUDO_UID:-$(id -u)}"
    local real_gid="${SUDO_GID:-$(id -g)}"

    mkdir -p "$log_dir"

    if [[ "$UID" == 0 && -n "${SUDO_USER:-}" ]]; then
        chown "$real_uid:$real_gid" "$log_dir"
        local parent_dir
        parent_dir="$(dirname "$log_dir")"
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

    local logs=()
    while IFS= read -r log; do
        [[ -n "$log" ]] && logs+=("$log")
    done < <(find "$log_dir" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | cut -d' ' -f2-)
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
    local timestamp
    timestamp="$(date '+%Y%m%d_%H%M%S')"
    echo "$log_dir/${prefix}_${timestamp}.log"
}

create_log_file() {
    local log_file="$1"
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
    if [[ "$(uname)" == "Darwin" ]]; then
        nix_tool_processes=$(ps ax -o command | tail -n +2 | grep -E "nix (build|eval|flake|gc)" | grep -v grep | wc -l) || nix_tool_processes=0
    else
        nix_tool_processes=$(ps ax -o stat,command | tail -n +2 | grep -E "nix (build|eval|flake|gc)" | grep -v grep | awk '$1 ~ /^(R|Rs|Rl|S\+)$/' | wc -l) || nix_tool_processes=0
    fi

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
        config_json=$(cat "$config_file")
    elif [[ -f "$HOME/.config/nx/config.json" ]]; then
        config_file="$HOME/.config/nx/config.json"
        config_json=$(cat "$config_file")
    else
        echo -e "${YELLOW}No nx config found, using defaults${RESET}" >&2
        config_json=""
    fi

    NX_CONFIG_LOADED=1
    COMMIT_VERIFICATION_NXCORE=$(get_config_value "security.commitVerification.nxcore" "$config_json")
    COMMIT_VERIFICATION_NXCONFIG=$(get_config_value "security.commitVerification.nxconfig" "$config_json")
    NX_DEPLOYMENT_MODE=$(get_config_value "deploymentMode" "$config_json")

    export NX_CONFIG_LOADED COMMIT_VERIFICATION_NXCORE COMMIT_VERIFICATION_NXCONFIG NX_DEPLOYMENT_MODE
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

run_bump() {
    local commit="$1"
    local push="$2"
    local exit_cleanup="${3:-}"

    if [[ "$commit" == "true" ]] && ! git diff --quiet HEAD -- flake.lock .label; then
        echo -e "${YELLOW}Warning: flake.lock or .label already have local changes.${RESET}"
        echo -e -n "${CYAN}Commit bump anyway? [${GREEN}y${CYAN}/${RED}N${CYAN}]${RESET} "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            commit=false
        fi
    fi

    echo -e "${CYAN}Bumping core input...${RESET}"
    nix flake update core 2> >(grep -v "warning: Git tree.*is dirty" >&2)
    echo -e "Updated ${WHITE}core${RESET} flake lock"
    echo

    rm -rf "$CONFIG_DIR/.core-state"
    if [[ -d "$NXCORE_DIR/.core-state" ]]; then
        cp -r "$NXCORE_DIR/.core-state" "$CONFIG_DIR/.core-state"
    fi

    local use_dir="$CONFIG_DIR"
    if [[ -d "$CONFIG_DIR/.git" && -d "$NXCORE_DIR/.git" ]]; then
        local config_timestamp core_timestamp

        config_timestamp=$(
            git -C "$CONFIG_DIR" log --pretty=format:'%ct%x09%s' |
            awk -F'\t' '$2 !~ /^Bump core at: / { print $1; exit }' || true
        )

        core_timestamp=$(get_latest_commit_timestamp "$NXCORE_DIR")
        if [[ -z "${config_timestamp:-}" || "$core_timestamp" -gt "$config_timestamp" ]]; then
            use_dir="$NXCORE_DIR"
        fi
    elif [[ -d "$NXCORE_DIR/.git" ]]; then
        use_dir="$NXCORE_DIR"
    fi

    local commit_ref="HEAD"
    if [[ "$use_dir" == "$CONFIG_DIR" ]]; then
        commit_ref=$(
            git -C "$CONFIG_DIR" log --pretty=format:'%H%x09%s' |
            awk -F'\t' '$2 !~ /^Bump core at: / { print $1; exit }' || true
        )
    fi

    if [[ "$commit_ref" == "" ]]; then
      commit_ref="HEAD"
    fi

    local commit_msg label
    commit_msg=$(git -C "$use_dir" log -1 --pretty=format:"%s" "$commit_ref" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g' | awk '{if(length($0)>25) print substr($0,1,24)"-"; else print $0}' | sed 's/--$/-/')
    label="$(git -C "$use_dir" log -1 --pretty=format:"$(git -C "$use_dir" branch --show-current).%cd.${commit_msg}" --date=format:'%d-%m-%y.%H:%M' | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9:_.-]//g')"
    echo "$label" > "$CONFIG_DIR/.label"
    echo -e "Generated label ${GREEN}$label${RESET}"
    echo

    if [[ "$commit" == "true" ]] && ! git diff --quiet HEAD -- flake.lock .label; then
        local STASH_POP
        if git diff --cached --quiet -- flake.lock .label; then
            STASH_POP="git stash pop --index"
        else
            STASH_POP="git stash pop"
        fi
        local pre_stash post_stash
        pre_stash=$(git rev-parse --verify refs/stash 2>/dev/null || echo "none")
        echo -e "${CYAN}Stashing other changes...${RESET}"
        git stash push --include-untracked -- ':(exclude)flake.lock' ':(exclude).label' ':(exclude).core-state'
        post_stash=$(git rev-parse --verify refs/stash 2>/dev/null || echo "none")
        if [[ "$pre_stash" != "$post_stash" ]]; then
            if [[ -n "$exit_cleanup" ]]; then
                # shellcheck disable=SC2064
                trap "$STASH_POP; $exit_cleanup" EXIT
            else
                # shellcheck disable=SC2064
                trap "$STASH_POP" EXIT
            fi
        fi
        echo

        echo -e "${CYAN}Committing bump...${RESET}"
        git add "$CONFIG_DIR/flake.lock" "$CONFIG_DIR/.label"
        if [[ -d "$CONFIG_DIR/.core-state" ]]; then
            git add "$CONFIG_DIR/.core-state"
        else
            git rm -r --cached --ignore-unmatch "$CONFIG_DIR/.core-state" >/dev/null 2>&1 || true
        fi
        git commit -m "Bump core at: $label"
        echo -e "Committed ${WHITE}flake.lock${RESET} and ${WHITE}.label${RESET}"
        echo

        if [[ "$push" == "true" ]]; then
            echo -e "${CYAN}Pushing config ${YELLOW}(Authentication required)${CYAN}...${RESET}"
            git push
            echo -e "Pushed ${WHITE}config${RESET}"
            echo
        fi
    fi
}

diff_store_paths() {
    local exact_names_to_ignore=(
      "man-cache"
      "manifest-for-users.json"
      "manifest.json"
      "sops-nix.service"
      "sops-nix-user"
      "source"
      "hm_fontconfigconf.d10hmfonts.conf"
      "hm_.localsharenvimtemplatesnixnixmoduleraw.md"
      "hm_.localsharenvimtemplatesnixnixmodule.tpl"
      "hm_LibraryFonts.homemanagerfontsversion"
      "home-manager-generation"
      "home-manager-path"
      "home-manager-files"
      "home-manager-applications"
      "home-manager-fonts"
      "system-units"
      "user-environment"
      "X-Restart-Triggers-systemd-modules-load"
      "unit-systemd-modules-load.service"
      "hm_.configfishcompletionsnx.fish"
      "hm_.localsharebashcompletioncompletionsnx"
      "wallpaper.jpg"
      "hm_wallpaper.jpg"
      "plymouth-initrd-themes"
      "flattenedGtkTheme"
      "ghostty-stylix-theme"
      "gtk.css"
      "stylix-plymouth"
      "themed-nix-snowflake"
      "X-Restart-Triggers-dbus-broker"
      "X-Restart-Triggers-polkit"
      "hm_autostartstylixactivatekde.desktop"
      "hm-dconf.ini"
      "system_fish-completions"
      "hm_gdugdu.yaml"
      "etc-man_db.conf"
      "etc"
    )
    local suffixes_to_ignore=(
      "-source"
      "_themeStylix.xml"
      "theme.css"
      "-theme"
      "-themes"
      "-style.css"
      "-css.css"
    )
    local changed_prefixes_to_ignore=(
      "nixos-system-"
      "etc-nx-theme-active-"
      "widescreen-"
      "base16-"
      "etc-nx-theme-"
      "nixos-icons-"
      ".Xresources"
    )
    local add_removal_prefixes_to_ignore=(
      "nixos-system-"
      "etc-nx-theme-active-"
    )
    local paths_require_attention=()
    local prefixes_require_attention=("unit-home-manager-")
    local paths_require_reboot=()
    local prefixes_require_reboot=()
    local paths_look_suspicious=()
    local prefixes_look_suspicious=()

    _diff_store_paths_severity_for_name() {
        local name="$1"

        for p in "${paths_look_suspicious[@]+"${paths_look_suspicious[@]}"}"; do
            [[ "$name" == "$p" ]] && { echo "suspicious"; return; }
        done
        for p in "${prefixes_look_suspicious[@]+"${prefixes_look_suspicious[@]}"}"; do
            [[ "$name" == "$p"* ]] && { echo "suspicious"; return; }
        done

        for p in "${paths_require_reboot[@]+"${paths_require_reboot[@]}"}"; do
            [[ "$name" == "$p" ]] && { echo "reboot"; return; }
        done
        for p in "${prefixes_require_reboot[@]+"${prefixes_require_reboot[@]}"}"; do
            [[ "$name" == "$p"* ]] && { echo "reboot"; return; }
        done

        for p in "${paths_require_attention[@]+"${paths_require_attention[@]}"}"; do
            [[ "$name" == "$p" ]] && { echo "attention"; return; }
        done
        for p in "${prefixes_require_attention[@]+"${prefixes_require_attention[@]}"}"; do
            [[ "$name" == "$p"* ]] && { echo "attention"; return; }
        done

        echo ""
    }

    local matched_entries_require_attention=()
    local matched_entries_require_reboot=()
    local matched_entries_look_suspicious=()

    _diff_store_paths_record_match() {
        local severity="$1"
        local entry="${3:-}"

        [[ -z "$severity" ]] && return

        if [[ "$severity" == "attention" ]]; then
            [[ -n "$entry" ]] && matched_entries_require_attention+=("$entry")
        elif [[ "$severity" == "reboot" ]]; then
            [[ -n "$entry" ]] && matched_entries_require_reboot+=("$entry")
        elif [[ "$severity" == "suspicious" ]]; then
            [[ -n "$entry" ]] && matched_entries_look_suspicious+=("$entry")
        fi
    }

    _diff_store_paths_print_matches() {
        if [[ ! -f /etc/NIXOS ]]; then
          matched_entries_require_reboot=()
        fi

        local print_warnings=0
        if (( ${#matched_entries_require_attention[@]} > 0 || ${#matched_entries_require_reboot[@]} > 0 || ${#matched_entries_look_suspicious[@]} > 0 )); then
          print_warnings=1
        fi

        if (( print_warnings )); then
            echo
            echo
            echo -e "${CYAN}=== Attention! ===${RESET}"
        fi

        if (( ${#matched_entries_require_attention[@]} > 0 )); then
            echo
            echo -e "${YELLOW}== Requires review ==${RESET}"
            for e in "${matched_entries_require_attention[@]+"${matched_entries_require_attention[@]}"}"; do
                echo -e "  $e"
            done
        fi

        if (( ${#matched_entries_require_reboot[@]} > 0 )); then
            echo
            echo -e "${ORANGE}== Requires reboot ==${RESET}"
            for e in "${matched_entries_require_reboot[@]+"${matched_entries_require_reboot[@]}"}"; do
                echo -e "  $e"
            done
        fi

        if (( ${#matched_entries_look_suspicious[@]} > 0 )); then
            echo
            echo -e "${RED}== Looks suspicious (do NOT sync without checking first!) ==${RESET}"
            for e in "${matched_entries_look_suspicious[@]+"${matched_entries_look_suspicious[@]}"}"; do
                echo -e "  $e"
            done
        fi

        if (( print_warnings )); then
          echo
        fi
    }

    local old="$1" new="$2"

    local old_file new_file
    old_file="$(mktemp)"
    new_file="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$old_file' '$new_file'" RETURN

    nix path-info -r "$old" 2>/dev/null | while IFS= read -r path; do
        local stripped="${path#/nix/store/}"
        printf '%s\t%s\n' "${stripped:0:32}" "${stripped:33}"
    done | sort -t$'\t' -k2 > "$old_file"

    nix path-info -r "$new" 2>/dev/null | while IFS= read -r path; do
        local stripped="${path#/nix/store/}"
        printf '%s\t%s\n' "${stripped:0:32}" "${stripped:33}"
    done | sort -t$'\t' -k2 > "$new_file"

    local old_names new_names
    old_names="$(mktemp)"
    new_names="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$old_file' '$new_file' '$old_names' '$new_names'" RETURN

    cut -f2 "$old_file" | sort -u > "$old_names"
    cut -f2 "$new_file" | sort -u > "$new_names"

    local out_file
    out_file="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$old_file' '$new_file' '$old_names' '$new_names' '$out_file'" RETURN

    while IFS= read -r name; do
        local hash
        local severity full_path entry

        for p in "${add_removal_prefixes_to_ignore[@]+"${add_removal_prefixes_to_ignore[@]}"}"; do
          [[ "$name" == "$p"* ]] && continue 2
        done
        for p in "${exact_names_to_ignore[@]+"${exact_names_to_ignore[@]}"}"; do
          [[ "$name" == "$p" ]] && continue 2
        done
        for s in "${suffixes_to_ignore[@]+"${suffixes_to_ignore[@]}"}"; do
          [[ "$name" == *"$s" ]] && continue 2
        done

        [[ "$name" =~ -[0-9]+\.[0-9]+([.][0-9]+)*([a-zA-Z]+[0-9]*)?(-[0-9A-Za-z]+)*$ ]] && continue
        [[ "$name" =~ (-wrapped|-fish-completions|\.manpath)$ ]] && continue

        hash="$(grep -m1 "	${name}$" "$new_file" | cut -f1)"
        full_path="/nix/store/${hash}-${name}"
        severity="$(_diff_store_paths_severity_for_name "$name")"
        entry="${GREEN}[A]${RESET} ${WHITE}${name}${RESET}  ${GRAY}${full_path}${RESET}"
        _diff_store_paths_record_match "$severity" "$full_path" "$entry"
        echo -e "${GREEN}[A]${RESET} ${WHITE}${name}${RESET}  ${GRAY}/nix/store/${hash}-${name}${RESET}"
    done < <(comm -13 "$old_names" "$new_names") >> "$out_file"

    while IFS= read -r name; do
        local hash
        local severity full_path entry

        for p in "${add_removal_prefixes_to_ignore[@]+"${add_removal_prefixes_to_ignore[@]}"}"; do
          [[ "$name" == "$p"* ]] && continue 2
        done
        for p in "${exact_names_to_ignore[@]+"${exact_names_to_ignore[@]}"}"; do
          [[ "$name" == "$p" ]] && continue 2
        done
        for s in "${suffixes_to_ignore[@]+"${suffixes_to_ignore[@]}"}"; do
          [[ "$name" == *"$s" ]] && continue 2
        done

        [[ "$name" =~ -[0-9]+\.[0-9]+([.][0-9]+)*([a-zA-Z]+[0-9]*)?(-[0-9A-Za-z]+)*$ ]] && continue
        [[ "$name" =~ (-wrapped|-fish-completions|\.manpath)$ ]] && continue

        hash="$(grep -m1 "	${name}$" "$old_file" | cut -f1)"
        full_path="/nix/store/${hash}-${name}"
        severity="$(_diff_store_paths_severity_for_name "$name")"
        entry="${RED}[R]${RESET} ${WHITE}${name}${RESET}  ${GRAY}${full_path}${RESET}"
        _diff_store_paths_record_match "$severity" "$full_path" "$entry"
        echo -e "${RED}[R]${RESET} ${WHITE}${name}${RESET}  ${GRAY}/nix/store/${hash}-${name}${RESET}"
    done < <(comm -23 "$old_names" "$new_names") >> "$out_file"

    local changed_file
    changed_file="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -f '$old_file' '$new_file' '$old_names' '$new_names' '$out_file' '$changed_file'" RETURN

    num_entries=0
    while IFS=$'\t' read -r name old_hash new_hash; do
        num_entries=$((num_entries+1))

        if [[ "$old_hash" != "$new_hash" ]]; then
            echo "$name" >> "$changed_file"
        fi
    done < <(awk -F'\t' '
        NR==FNR {
            if ($2 in old) old[$2] = old[$2] " " $1; else old[$2] = $1
            next
        }
        {
            if (prev != "" && $2 != prev && prev in old) {
                print prev "\t" old[prev] "\t" cur[prev]
            }
            if ($2 in cur) cur[$2] = cur[$2] " " $1; else cur[$2] = $1
            prev = $2
        }
        END {
            if (prev != "" && prev in old) print prev "\t" old[prev] "\t" cur[prev]
        }
    ' <(sort -t$'\t' -k2,2 -k1,1 "$old_file") <(sort -t$'\t' -k2,2 -k1,1 "$new_file"))

    local only_issue_etc=true
    while IFS= read -r name; do
        if [[ "$name" != "issue" && "$name" != "etc" ]]; then
            only_issue_etc=false
            break
        fi
    done < "$changed_file"

    while IFS= read -r name; do
        [[ "$name" == "issue" ]] && continue
        for p in ${changed_prefixes_to_ignore[@]+"${changed_prefixes_to_ignore[@]}"}; do
          [[ "$name" == "$p" || "$name" == "$p"* ]] && continue 2
        done
        for p in "${exact_names_to_ignore[@]+"${exact_names_to_ignore[@]}"}"; do
          [[ "$name" == "$p" ]] && continue 2
        done
        for s in "${suffixes_to_ignore[@]+"${suffixes_to_ignore[@]}"}"; do
          [[ "$name" == *"$s" ]] && continue 2
        done
        $only_issue_etc && [[ "$name" == "etc" ]] && continue

        [[ "$name" =~ -[0-9]+\.[0-9]+([.][0-9]+)*([a-zA-Z]+[0-9]*)?(-[0-9A-Za-z]+)*$ ]] && continue
        [[ "$name" =~ (-wrapped|-fish-completions|\.manpath)$ ]] && continue

        local old_hashes=() new_hashes=()

        while IFS= read -r h; do
            old_hashes+=("$h")
        done < <(awk -F $'\t' -v n="$name" '$2 == n { print $1 }' "$old_file" | sort -u)

        while IFS= read -r h; do
            new_hashes+=("$h")
        done < <(awk -F $'\t' -v n="$name" '$2 == n { print $1 }' "$new_file" | sort -u)

        if (( ${#old_hashes[@]} == 0 || ${#new_hashes[@]} == 0 )); then
            continue
        fi

        local only_old=() only_new=()
        for oh in "${old_hashes[@]}"; do
            local found=false
            for nh in "${new_hashes[@]}"; do
                [[ "$oh" == "$nh" ]] && { found=true; break; }
            done
            $found || only_old+=("$oh")
        done
        for nh in "${new_hashes[@]}"; do
            local found=false
            for oh in "${old_hashes[@]}"; do
                [[ "$nh" == "$oh" ]] && { found=true; break; }
            done
            $found || only_new+=("$nh")
        done

        if (( ${#only_old[@]} == 0 && ${#only_new[@]} == 0 )); then
            continue
        fi

        local severity
        severity="$(_diff_store_paths_severity_for_name "$name")"
        _diff_store_paths_record_match "$severity" "" "${YELLOW}[C]${RESET} ${WHITE}${name}${RESET}"
        echo -e "${YELLOW}[C]${RESET} ${WHITE}${name}${RESET}"
        if (( ${#only_old[@]} == 1 && ${#only_new[@]} == 1 )); then
            _diff_store_paths_record_match "$severity" "/nix/store/${only_old[0]}-${name}" "    ${GRAY}/nix/store/${only_old[0]}-${name}${RESET} ${GRAY}/nix/store/${only_new[0]}-${name}${RESET}"
            _diff_store_paths_record_match "$severity" "/nix/store/${only_new[0]}-${name}"
            echo -e "    ${GRAY}/nix/store/${only_old[0]}-${name}${RESET} ${GRAY}/nix/store/${only_new[0]}-${name}${RESET}"
        else
            for oh in "${only_old[@]+"${only_old[@]}"}"; do
                _diff_store_paths_record_match "$severity" "/nix/store/${oh}-${name}" "    ${RED}old${RESET} ${GRAY}/nix/store/${oh}-${name}${RESET}"
                echo -e "    ${RED}old${RESET} ${GRAY}/nix/store/${oh}-${name}${RESET}"
            done
            for nh in "${only_new[@]+"${only_new[@]}"}"; do
                _diff_store_paths_record_match "$severity" "/nix/store/${nh}-${name}" "    ${GREEN}new${RESET} ${GRAY}/nix/store/${nh}-${name}${RESET}"
                echo -e "    ${GREEN}new${RESET} ${GRAY}/nix/store/${nh}-${name}${RESET}"
            done
        fi
    done < "$changed_file" >> "$out_file"

    echo -en "${CYAN}${YELLOW}$num_entries${CYAN} store paths${CYAN}${RESET} "
    if [[ -s "$out_file" ]]; then
        echo -e "${ORANGE}-> Store closures differ.${RESET}"
        echo
        cat "$out_file"
        _diff_store_paths_print_matches
    else
        echo -e "${WHITE}-> Store closures are identical.${RESET}"
    fi
}

diff_packages() {
    local old="$1" new="$2"
    DIFF_OUTPUT="$(nvd --color=always --version-highlight=xmas diff "$old" "$new" 2>&1)"

    if echo "$DIFF_OUTPUT" | grep -Eq 'Closure size: ([0-9]+) -> \1 \(([0-9]+) paths added, \2 paths removed, delta \+0,'; then
      echo -e "${WHITE}Packages are identical.${RESET}"
    else
      echo "$DIFF_OUTPUT"
    fi
}
