#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "impermanence"

PROFILE_PATH="$(retrieve_active_profile_path)"

check_nixos() {
  if [[ ! -f /etc/NIXOS ]]; then
    echo -e "${RED}Error: This command only works on NixOS systems${RESET}" >&2
    exit 1
  fi
}

check_impermanence() {
  if [[ ! -f /etc/IMPERMANENCE ]]; then
    echo -e "${RED}Error: This system is not configured with impermanence${RESET}" >&2
    echo -e "The ${WHITE}/etc/IMPERMANENCE${RESET} marker file is missing" >&2
    echo "This usually means impermanence was not set up during installation" >&2
    exit 1
  fi
}

get_main_username() {
  local hostname="$(hostname)"
  local full_profile="$(construct_profile_name "$hostname")"
  
  if [[ -d "$CONFIG_DIR" ]]; then
    local username
    username="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" ".#hosts.$full_profile.host.mainUser.username" 2>/dev/null || echo "null")"
    if [[ -n "$username" && "$username" != "null" && "$username" != "\"null\"" ]]; then
      echo "${username//\"/}"
      return 0
    fi
  fi
  
  echo -e "${RED}Error: could not determine main user name!${RESET}" >&2
  exit 1
}

show_help() {
  cat << 'EOF'
Usage:
    nx impermanence <command>

Description:
    Manages impermanence on NixOS systems.

SUBCOMMANDS:
    check [OPTIONS]      List files/directories in ephemeral root (not persisted)
                        OPTIONS:
                          --home           Show only paths under /home
                          --system         Show only system paths (excludes /home and /persist)
                          --filter <keyword>  Filter results containing keyword (can be used multiple times)
    logs                 Show impermanence rollback logs
    help                 Show this help message
EOF
}

subcommand_check() {
  local show_home_only=false
  local show_system_only=false
  local filters=()
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --home)
        show_home_only=true
        shift
        ;;
      --system)
        show_system_only=true
        shift
        ;;
      --filter)
        if [[ $# -lt 2 ]]; then
          echo -e "${RED}Error: --filter requires a keyword argument${RESET}" >&2
          exit 1
        fi
        filters+=("$2")
        shift 2
        ;;
      *)
        echo -e "${RED}Error: Unknown option: ${WHITE}$1${RESET}" >&2
        echo -e "Usage: ${WHITE}nx impermanence check [--home] [--system] [--filter <keyword>]...${RESET}" >&2
        exit 1
        ;;
    esac
  done
  
  if [[ "$show_home_only" == "true" && "$show_system_only" == "true" ]]; then
    echo -e "${RED}Error: --home and --system cannot be used together${RESET}" >&2
    exit 1
  fi
  
  local sudo=""
  echo "Checking for ephemeral files/directories..."
  if [[ "$show_home_only" == "true" ]]; then
    echo "(filtering: /home paths only)"
  elif [[ "$show_system_only" == "true" ]]; then
    echo "(filtering: system paths only, excluding /home and /persist)"
    sudo="sudo"
  else
    sudo="sudo"
  fi

  if [[ ${#filters[@]} -gt 0 ]]; then
    echo "(keyword filters: ${filters[*]})"
  fi
  echo
  
  local hostname="$(hostname)"
  local username="$(get_main_username)"
  local persist_system="/persist"
  local persist_user_full="/persist/home/$username"
  
  local user_home="/home/$username"
  if [[ -d "$CONFIG_DIR" ]]; then
    local full_profile="$(construct_profile_name "$hostname")"
    local home_path="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" \
      ".#nixosConfigurations.$full_profile.config.users.users.$username.home" 2>/dev/null || echo "null")"
    if [[ -n "$home_path" && "$home_path" != "null" && "$home_path" != "\"null\"" ]]; then
      user_home="${home_path//\"/}"
    fi
  fi
  
  local system_dirs=""
  local system_files=""
  local user_dirs=""
  local user_files=""
  
  if [[ -d "$CONFIG_DIR" ]]; then
    local full_profile="$(construct_profile_name "$hostname")"
    
    system_dirs="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" \
      ".#nixosConfigurations.$full_profile.config.environment.persistence.\"$persist_system\".directories" 2>/dev/null \
      | jq -r '.[]?' 2>/dev/null || echo "")"
      
    system_files="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" \
      ".#nixosConfigurations.$full_profile.config.environment.persistence.\"$persist_system\".files" 2>/dev/null \
      | jq -r '.[]?' 2>/dev/null || echo "")"
      
    user_dirs="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" \
      ".#nixosConfigurations.$full_profile.config.home-manager.users.$username.home.persistence.\"$persist_user_full\".directories" 2>/dev/null \
      | jq -r '.[]?' 2>/dev/null || echo "")"
      
    user_files="$(nix eval --json --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" \
      ".#nixosConfigurations.$full_profile.config.home-manager.users.$username.home.persistence.\"$persist_user_full\".files" 2>/dev/null \
      | jq -r '.[]?' 2>/dev/null || echo "")"
  fi
  
  local ephemeral_items=()
  local search_path="/"
  if [[ "$show_home_only" == "true" ]]; then
    search_path="$user_home"
  fi
  
  while IFS= read -r item; do
    local item_path="${item#/}"
    
    if ! echo "$system_dirs $system_files $user_dirs $user_files" | grep -q "$item_path" && ! mount | grep -q " on /$item_path type "; then
      local full_path="/$item_path"
      
      if [[ "$show_system_only" == "true" ]]; then
        if [[ "$full_path" =~ ^$user_home/ || "$full_path" =~ ^/persist/ ]]; then
          continue
        fi
      fi
      
      if [[ ${#filters[@]} -gt 0 ]]; then
        local match_found=false
        for filter in "${filters[@]}"; do
          if echo "$full_path" | grep -q "$filter"; then
            match_found=true
            break
          fi
        done
        if [[ "$match_found" != "true" ]]; then
          continue
        fi
      fi
      
      ephemeral_items+=("$full_path")
    fi
  done < <($sudo find "$search_path" -xdev -type f -o -type d 2>/dev/null | grep -v "^$search_path$" | sort)
  
  if [[ ${#ephemeral_items[@]} -gt 0 ]]; then
    echo "⚠️  Ephemeral files/directories (will be lost on reboot):"
    
    local dirs=()
    local files=()
    
    for item in "${ephemeral_items[@]}"; do
      local display_item="$item"
      if [[ "$show_home_only" == "true" && "$item" =~ ^$user_home/ ]]; then
        display_item="${item#$user_home/}"
      fi
      
      if [[ -d "$item" ]]; then
        dirs+=("$display_item/")
      else
        files+=("$display_item")
      fi
    done
    
    local dir_printed=0
    for dir in "${dirs[@]}"; do
      echo "  Dir  -> $dir"
      dir_printed=1
    done

    if (( dir_printed )); then
      echo
    fi

    for file in "${files[@]}"; do
      echo "  File -> $file"
    done
    
    echo
    echo "Add missing files and folders to /persist:"
    echo
    echo " For home modules:"
    echo '  home.persistence."${self.persist}" = { directories = [...], files = [...] };'
    echo
    echo " For system modules:"
    echo '  environment.persistence."${self.persist}" = { directories = [...], files = [...] };'
    echo
    echo " Note: Files may not work depending on the program."
    echo "       Specifying directories for bind mounts is generally"
    echo "       the recommended way."
    echo
    echo " After that move the files and folders to /persist and then rebuild the system."
  else
    echo "All files are properly persisted!"
  fi
}

subcommand_logs() {
  local log_file="/var/log/nx/impermanence/rollback.log"
  
  if [[ ! -f "$log_file" ]]; then
    echo -e "${RED}No rollback logs found at ${WHITE}$log_file${RESET}" >&2
    exit 1
  fi
  
  local pager="${PAGER:-less}"
  "$pager" "$log_file"
}

main() {
  check_nixos
  check_impermanence
  
  case "${1:-help}" in
    check)
      shift
      subcommand_check "$@"
      ;;
    logs)
      subcommand_logs
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Error: Unknown subcommand: ${WHITE}$1${RESET}" >&2
      echo -e "Run '${WHITE}nx impermanence help${RESET}' for usage information." >&2
      exit 1
      ;;
  esac
}
main "$@"
