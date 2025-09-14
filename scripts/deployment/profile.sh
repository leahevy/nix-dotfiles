#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
simple_deployment_script_setup "profile"

PROFILE_PATH="$(retrieve_active_profile_path)"

show_help() {
  cat << 'EOF'
Usage:
    nx profile [SUBCOMMAND]

Description:
    Manage NX profiles - navigate to profile directories and edit configurations.

SUBCOMMANDS:
    (no args)               Navigate to active profile directory
    user                    Navigate to integrated user directory (NixOS only)
    edit                    Edit active profile configuration file
    user edit               Edit integrated user configuration file (NixOS only)
    select <PROFILE>        Set active profile name
    reset                   Reset to default profile
    help                    Show this help message

EXAMPLES:
    nx profile              # Open shell in active profile directory
    nx profile edit         # Edit main profile configuration file
    nx profile select myhost # Set active profile to 'myhost'
    nx profile reset        # Reset to default profile
EOF
}

resolve_active_profile_base() {
    local full_profile
    full_profile="$(retrieve_active_profile 2>/dev/null | tail -1)"
    local base_profile="${full_profile%--*}"
    echo "$base_profile"
}

resolve_active_profile_dir() {
    local base_profile
    base_profile="$(resolve_active_profile_base)"
    
    if [[ -e /etc/NIXOS ]]; then
        echo "$CONFIG_DIR/profiles/nixos/$base_profile"
    else
        echo "$CONFIG_DIR/profiles/home-standalone/$base_profile"
    fi
}

resolve_user_profile_dir() {
    ensure_nixos_only "profile user"
    local full_profile
    local username
    full_profile="$(retrieve_active_profile 2>/dev/null | tail -1)"
    username="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" ".#hosts.$full_profile.host.mainUser.username" 2>/dev/null || echo "null")"
    username="${username//\"/}"
    
    if [[ "$username" == "null" || -z "$username" ]]; then
        echo -e "${RED}Error: Could not resolve mainUser.username for profile ${WHITE}$full_profile${RESET}" >&2
        exit 1
    fi
    
    echo "$CONFIG_DIR/profiles/home-integrated/$username"
}

resolve_profile_config_file() {
    local profile_dir
    profile_dir="$(resolve_active_profile_dir)"
    local base_profile
    base_profile="$(resolve_active_profile_base)"
    echo "$profile_dir/$base_profile.nix"
}

resolve_user_config_file() {
    local user_dir
    user_dir="$(resolve_user_profile_dir)"
    local full_profile
    local username
    full_profile="$(retrieve_active_profile 2>/dev/null | tail -1)"
    username="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" ".#hosts.$full_profile.host.mainUser.username" 2>/dev/null || echo "null")"
    username="${username//\"/}"
    echo "$user_dir/$username.nix"
}

open_shell_in_dir() {
    local target_dir="$1"
    
    if [[ ! -d "$target_dir" ]]; then
        echo -e "${RED}Error: Directory not found: ${WHITE}$target_dir${RESET}" >&2
        exit 1
    fi
    
    if [[ -x "$HOME/.nix-profile/bin/fish" ]] && [[ -f "$HOME/.config/fish/config.fish" ]]; then
        CURRENT_SHELL="fish"
    elif [[ -x "$HOME/.nix-profile/bin/zsh" ]] && [[ -f "$HOME/.config/zsh/.zshrc" ]]; then
        CURRENT_SHELL="zsh"
    else
        CURRENT_SHELL="$(basename "$SHELL")"
    fi
    
    case "$CURRENT_SHELL" in
        bash)
            (cd "$target_dir" && exec "$SHELL" --rcfile <(echo "cd \"$target_dir\"") -i)
            ;;
        zsh)
            (cd "$target_dir" && exec "$SHELL" -i)
            ;;
        fish)
            (cd "$target_dir" && exec "$SHELL")
            ;;
        *)
            (cd "$target_dir" && exec "$SHELL" -i)
            ;;
    esac
}

edit_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo -e "${RED}Error: File not found: ${WHITE}$file_path${RESET}" >&2
        exit 1
    fi
    
    exec "${EDITOR:-vim}" "$file_path"
}

subcommand_navigate() {
    local profile_dir
    profile_dir="$(resolve_active_profile_dir)"
    echo -e "${GREEN}Opening shell in profile directory: ${WHITE}$profile_dir${RESET}"
    open_shell_in_dir "$profile_dir"
}

subcommand_user_navigate() {
    local user_dir
    user_dir="$(resolve_user_profile_dir)"
    echo -e "${GREEN}Opening shell in user directory: ${WHITE}$user_dir${RESET}"
    open_shell_in_dir "$user_dir"
}

subcommand_edit() {
    local config_file
    config_file="$(resolve_profile_config_file)"
    echo -e "${GREEN}Editing profile config: ${WHITE}$config_file${RESET}"
    edit_file "$config_file"
}

subcommand_user_edit() {
    local user_config_file
    user_config_file="$(resolve_user_config_file)"
    echo -e "${GREEN}Editing user config: ${WHITE}$user_config_file${RESET}"
    edit_file "$user_config_file"
}

subcommand_select() {
    local profile_name="${1:-}"
    
    if [[ "$profile_name" =~ ^- ]]; then
        echo -e "${RED}Unknown option: ${WHITE}$profile_name${RESET}" >&2
        echo -e "${RED}Expected: ${WHITE}<PROFILE_NAME>${RESET}" >&2
        exit 1
    fi
    
    if [[ "$profile_name" = "" ]]; then
        echo -e "${RED}Expected: ${WHITE}<PROFILE_NAME>${RESET}" >&2
        exit 1
    fi
    
    echo -n "$profile_name" > .nx-profile.conf
    echo -e "${GREEN}Profile set to: ${WHITE}$profile_name${RESET}"
}

subcommand_reset() {
    if [[ -f .nx-profile.conf ]]; then
        rm .nx-profile.conf
        echo -e "${GREEN}Profile configuration reset - using default profile${RESET}"
    else
        echo -e "${YELLOW}No profile configuration found to reset${RESET}"
    fi
}

SUBCOMMAND="${1:-}"
shift || true

case "$SUBCOMMAND" in
    "")
        subcommand_navigate
        ;;
    "user")
        if [[ "${1:-}" == "edit" ]]; then
            subcommand_user_edit
        else
            subcommand_user_navigate
        fi
        ;;
    "edit")
        subcommand_edit
        ;;
    "select")
        subcommand_select "$@"
        ;;
    "reset")
        subcommand_reset
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown subcommand: ${WHITE}$SUBCOMMAND${RESET}" >&2
        echo -e "${RED}Run ${WHITE}nx profile help${RED} for usage information${RESET}" >&2
        exit 1
        ;;
esac
