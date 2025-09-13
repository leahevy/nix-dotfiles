#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "modules"

show_help() {
  cat << 'EOF'
Usage:
    nx modules <command>

Description:
    Manages and inspects NX modules.

SUBCOMMANDS:
    list [OPTIONS]          List available modules

                            OPTIONS:
                              --active          Show only active modules for current profile
                              --inactive        Show only inactive modules for current profile
                              --profile <name>  Use specific profile instead of current
                              --nixos           Force NixOS mode (host + user modules)
                              --standalone      Force standalone mode (user modules only)

    config [OPTIONS]        Show complete active configuration

                            OPTIONS:
                              --profile <name>  Use specific profile instead of current
                              --arch <arch>     Use specific architecture
                              --nixos           Force NixOS mode (host + user modules)
                              --standalone      Force standalone mode (user modules only)

    info <MODULE>           Show detailed module information
    edit <MODULE>           Open module file in editor (creates if doesn't exist)
    help                    Show this help message

MODULE FORMAT:
    INPUT.NAMESPACE.GROUP.MODULENAME   Example: common.home.shell.bash
EOF
}

subcommand_list() {
  local show_active_only=false
  local show_inactive_only=false
  local override_profile=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --active)
        show_active_only=true
        shift
        ;;
      --inactive)
        show_inactive_only=true
        shift
        ;;
      --profile)
        if [[ $# -lt 2 ]]; then
          echo -e "${RED}Error: --profile requires a profile name${RESET}" >&2
          exit 1
        fi
        override_profile="$2"
        shift 2
        ;;
      --nixos)
        force_nixos=true
        shift
        ;;
      --standalone)
        force_standalone=true
        shift
        ;;
      *)
        echo -e "${RED}Error: Unknown option: ${WHITE}$1${RESET}" >&2
        echo -e "Usage: ${WHITE}nx modules list [--active] [--inactive] [--profile <profile>] [--nixos] [--standalone]${RESET}" >&2
        exit 1
        ;;
    esac
  done
  
  if [[ "$show_active_only" == "true" && "$show_inactive_only" == "true" ]]; then
    echo -e "${RED}Error: --active and --inactive cannot be used together${RESET}" >&2
    exit 1
  fi
  
  if [[ "${force_nixos:-false}" == "true" && "${force_standalone:-false}" == "true" ]]; then
    echo -e "${RED}Error: --nixos and --standalone cannot be used together${RESET}" >&2
    exit 1
  fi
  
  echo -e "${YELLOW}Fetching module registry...${RESET}"
  echo
  local registry_json
  registry_json="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#modules" 2>/dev/null)"
  
  if [[ $? -ne 0 || -z "$registry_json" || "$registry_json" == "null" ]]; then
    echo -e "${RED}Error: Failed to fetch module registry${RESET}" >&2
    exit 1
  fi
  
  local profile
  if [[ -n "$override_profile" ]]; then
    profile="$override_profile"
    local base_profile="${profile%--*}"
    
    if [[ "${force_standalone:-false}" == "true" ]]; then
      local full_profile="$(construct_profile_name "$base_profile")"
      local user_exists="$(nix eval --override-input config "path:$CONFIG_DIR" ".#users" --apply "users: builtins.hasAttr \"$full_profile\" users" 2>/dev/null || echo "false")"
      if [[ "$user_exists" != "true" ]]; then
        echo -e "${RED}Error: User profile not found: ${WHITE}$base_profile${RESET}" >&2
        exit 1
      fi
    elif [[ -e /etc/NIXOS ]] || [[ "${force_nixos:-false}" == "true" ]]; then
      local full_profile="$(construct_profile_name "$base_profile")"
      local host_exists="$(nix eval --override-input config "path:$CONFIG_DIR" ".#hosts" --apply "hosts: builtins.hasAttr \"$full_profile\" hosts" 2>/dev/null || echo "false")"
      if [[ "$host_exists" != "true" ]]; then
        echo -e "${RED}Error: Host profile not found: ${WHITE}$base_profile${RESET}" >&2
        exit 1
      fi
    else
      local full_profile="$(construct_profile_name "$base_profile")"
      local user_exists="$(nix eval --override-input config "path:$CONFIG_DIR" ".#users" --apply "users: builtins.hasAttr \"$full_profile\" users" 2>/dev/null || echo "false")"
      if [[ "$user_exists" != "true" ]]; then
        echo -e "${RED}Error: User profile not found: ${WHITE}$base_profile${RESET}" >&2
        exit 1
      fi
    fi
  else
    profile="$(retrieve_active_profile)"
  fi
  local base_profile="${profile%--*}"
  
  local active_modules=""
  local host_modules=""
  local user_modules=""
  
  if [[ -n "$override_profile" ]]; then
    local full_profile="$(construct_profile_name "$base_profile")"
  else
    local full_profile="$profile"
  fi
  
  if [[ "${force_standalone:-false}" == "true" ]]; then
    active_modules="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#users.$full_profile.modules" 2>/dev/null || echo '{}')"
    user_modules="$active_modules"
  elif [[ -e /etc/NIXOS ]] || [[ "${force_nixos:-false}" == "true" ]]; then
    host_modules="$(timeout 30s nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$full_profile.host.modules" 2>/dev/null || echo '{}')"
    user_modules="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$full_profile.host.mainUser.modules" 2>/dev/null || echo '{}')"
  else
    active_modules="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#users.$full_profile.modules" 2>/dev/null || echo '{}')"
    user_modules="$active_modules"
  fi
  
  local system_modules=()
  local home_modules=()
  
  for module_type in "system" "home"; do
    while IFS='|' read -r module_id description; do
      [[ -z "$module_id" ]] && continue
      
      local input_name="${module_id%%.*}"
      [[ "$input_name" == "build" ]] && continue
      
      local is_active=false
      
      if [[ "$module_type" == "system" && -n "${host_modules:-}" && "$host_modules" != "{}" ]]; then
        local rest="${module_id#*.}"
        local namespace_name="${rest%%.*}"
        local rest2="${rest#*.}"
        local group_name="${rest2%%.*}"
        local module_name="${rest2#*.}"
        
        local module_active="$(echo "$host_modules" | jq -r --arg in "$input_name" --arg grp "$group_name" --arg mod "$module_name" '.[$in][$grp][$mod] // false | if type == "boolean" then . elif type == "object" then true else false end' 2>/dev/null || echo "false")"
        if [[ "$module_active" == "true" ]]; then
          is_active=true
        fi
      elif [[ "$module_type" == "home" && -n "${user_modules:-$active_modules}" ]]; then
        local check_modules="${user_modules:-$active_modules}"
        local rest="${module_id#*.}"
        local rest2="${rest#*.}"
        local group_name="${rest2%%.*}"
        local module_name="${rest2#*.}"
        
        local module_active="$(echo "$check_modules" | jq -r --arg in "$input_name" --arg grp "$group_name" --arg mod "$module_name" '.[$in][$grp][$mod] // false | if type == "boolean" then . elif type == "object" then true else false end' 2>/dev/null || echo "false")"
        if [[ "$module_active" == "true" ]]; then
          is_active=true
        fi
      fi
      
      if [[ "$show_active_only" == "true" && "$is_active" != "true" ]]; then
        continue
      fi
      if [[ "$show_inactive_only" == "true" && "$is_active" == "true" ]]; then
        continue
      fi
      
      local status_indicator=""
      if [[ -n "${host_modules:-}${user_modules:-$active_modules}" ]]; then
        if [[ "$is_active" == "true" ]]; then
          status_indicator="\033[1;32m●\033[0m "
        else
          status_indicator="\033[1;31m○\033[0m "
        fi
      fi
      
      local formatted_line="$(printf "  %b\033[1;37m%-40s\033[0m %s" "$status_indicator" "$module_id" "$description")"
      if [[ "$module_type" == "system" ]]; then
        system_modules+=("$formatted_line")
      else
        home_modules+=("$formatted_line")
      fi
    done < <(echo "$registry_json" | jq -r --arg mt "$module_type" '
      to_entries[] as $input |
      $input.key as $input_name |
      $input.value | to_entries[] as $modtype |
      $modtype.key as $modtype_name |
      $modtype.value | to_entries[] as $group |
      $group.key as $group_name |
      $group.value | to_entries[] as $module |
      $module.key as $module_name |
      $module.value as $module_data |
      select($module_data.moduleType == $mt) |
      "\($input_name).\($modtype_name).\($group_name).\($module_name)|\($module_data.description // "No description")"
    ')
  done
  
  if [[ ${#system_modules[@]} -gt 0 ]]; then
    local show_system_modules=false
    if [[ "${force_nixos:-false}" == "true" ]]; then
      show_system_modules=true
    elif [[ -e /etc/NIXOS ]]; then
      show_system_modules=true
    fi
    
    if [[ "$show_system_modules" == "true" ]]; then
      echo -e "${RED}System Modules:${RESET}"
      printf "%s\n" "${system_modules[@]}"
    fi
  fi
  
  if [[ ${#home_modules[@]} -gt 0 ]]; then
    if [[ ${#system_modules[@]} -gt 0 ]]; then
      echo
    fi
    echo -e "${RED}Home Modules:${RESET}"
    printf "%s\n" "${home_modules[@]}"
  fi
  
  if [[ ${#system_modules[@]} -eq 0 && ${#home_modules[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No modules found matching the specified criteria${RESET}" >&2
    exit 1
  fi
}

subcommand_info() {
  if [[ $# -eq 0 ]]; then
    echo -e "${RED}Error: MODULE argument required${RESET}" >&2
    echo -e "Usage: ${WHITE}nx modules info INPUT.NAMESPACE.GROUP.MODULENAME${RESET}" >&2
    exit 1
  fi
  
  local module_id="$1"
  if [[ ! "$module_id" =~ ^[^.]+\.[^.]+\.[^.]+\.[^.]+$ ]]; then
    echo -e "${RED}Error: Invalid module format. Expected: INPUT.NAMESPACE.GROUP.MODULENAME${RESET}" >&2
    exit 1
  fi
  
  local input_name="${module_id%%.*}"
  local rest="${module_id#*.}"
  local namespace_name="${rest%%.*}"
  local rest2="${rest#*.}"
  local group_name="${rest2%%.*}"
  local module_name="${rest2#*.}"
  
  echo -e "${YELLOW}Fetching module information...${RESET}"
  echo
  local module_info
  module_info="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#modules.$input_name.$namespace_name.$group_name.$module_name" 2>/dev/null || echo "null")"
  
  if [[ "$module_info" == "null" ]]; then
    echo -e "${RED}Error: Module not found: ${WHITE}$module_id${RESET}" >&2
    exit 1
  fi
  
  echo
  echo -e "${GREEN}Module Information: ${WHITE}$module_id${RESET}"
  echo
  
  local name=$(echo "$module_info" | jq -r '.name // "unknown"')
  local description=$(echo "$module_info" | jq -r '.description // "No description"')
  local group=$(echo "$module_info" | jq -r '.group // "unknown"')
  local input=$(echo "$module_info" | jq -r '.input // "unknown"')
  local moduleType=$(echo "$module_info" | jq -r '.moduleType // "unknown"')
  local path=$(echo "$module_info" | jq -r '.path // "unknown"')
  
  echo -e "  ${GREEN}name:${RESET} ${RED}\"$name\"${RESET}"
  echo -e "  ${GREEN}description:${RESET} ${RED}\"$description\"${RESET}"
  echo -e "  ${GREEN}group:${RESET} ${RED}\"$group\"${RESET}"
  echo -e "  ${GREEN}input:${RESET} ${RED}\"$input\"${RESET}"
  echo -e "  ${GREEN}moduleType:${RESET} ${RED}\"$moduleType\"${RESET}"
  echo -e "  ${GREEN}path:${RESET} ${RED}\"$path\"${RESET}"
}

subcommand_edit() {
  if [[ $# -eq 0 ]]; then
    echo -e "${RED}Error: MODULE argument required${RESET}" >&2
    echo -e "Usage: ${WHITE}nx modules edit INPUT.NAMESPACE.GROUP.MODULENAME${RESET}" >&2
    exit 1
  fi
  
  local module_id="$1"
  if [[ ! "$module_id" =~ ^[^.]+\.[^.]+\.[^.]+\.[^.]+$ ]]; then
    echo -e "${RED}Error: Invalid module format. Expected: INPUT.NAMESPACE.GROUP.MODULENAME${RESET}" >&2
    exit 1
  fi
  
  local input_name="${module_id%%.*}"
  local rest="${module_id#*.}"
  local namespace_name="${rest%%.*}"
  local rest2="${rest#*.}"
  local group_name="${rest2%%.*}"
  local module_name="${rest2#*.}"
  
  local core_inputs=("common" "linux" "darwin" "groups" "build" "config")
  local input_allowed=false
  for allowed_input in "${core_inputs[@]}"; do
    if [[ "$input_name" == "$allowed_input" ]]; then
      input_allowed=true
      break
    fi
  done
  
  if [[ "$input_allowed" != "true" ]]; then
    echo -e "${RED}Error: Module editing only allowed for core inputs: ${WHITE}${core_inputs[*]}${RESET}" >&2
    exit 1
  fi
  
  local base_path
  if [[ "$input_name" == "config" ]]; then
    base_path="$CONFIG_DIR"
  else
    base_path="$PWD/src/$input_name"
  fi
  
  local target_file="$base_path/modules/$namespace_name/$group_name/$module_name/$module_name.nix"
  
  local editor="${EDITOR:-nano}"
  echo -e "Opening ${WHITE}$target_file${RESET} with ${WHITE}$editor${RESET}..."
  "$editor" "$target_file"
}

subcommand_config() {
  local override_profile=""
  local override_arch=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --profile)
        if [[ $# -lt 2 ]]; then
          echo -e "${RED}Error: --profile requires a profile name${RESET}" >&2
          exit 1
        fi
        override_profile="$2"
        shift 2
        ;;
      --arch)
        if [[ $# -lt 2 ]]; then
          echo -e "${RED}Error: --arch requires an architecture${RESET}" >&2
          exit 1
        fi
        override_arch="$2"
        shift 2
        ;;
      --nixos)
        force_nixos=true
        shift
        ;;
      --standalone)
        force_standalone=true
        shift
        ;;
      *)
        echo -e "${RED}Error: Unknown option: ${WHITE}$1${RESET}" >&2
        echo -e "Usage: ${WHITE}nx modules config [--profile <profile>] [--arch <arch>] [--nixos] [--standalone]${RESET}" >&2
        exit 1
        ;;
    esac
  done
  
  if [[ "${force_nixos:-false}" == "true" && "${force_standalone:-false}" == "true" ]]; then
    echo -e "${RED}Error: --nixos and --standalone cannot be used together${RESET}" >&2
    exit 1
  fi
  
  local profile
  if [[ -n "$override_profile" ]]; then
    profile="$override_profile"
  else
    profile="$(retrieve_active_profile)"
  fi
  local base_profile="${profile%--*}"
  
  local arch
  if [[ -n "$override_arch" ]]; then
    arch="$override_arch"
  else
    arch="${profile##*--}"
    if [[ "$arch" == "$profile" ]]; then
      if [[ "${force_standalone:-false}" == "true" ]]; then
        arch="$(uname -m)"
        case "$arch" in
          arm64) arch="aarch64-$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
          x86_64) arch="x86_64-$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
        esac
      elif [[ -e /etc/NIXOS ]] || [[ "${force_nixos:-false}" == "true" ]]; then
        arch="$(uname -m)"
        case "$arch" in
          arm64) arch="aarch64-linux" ;;
          x86_64) arch="x86_64-linux" ;;
          *) arch="x86_64-linux" ;;
        esac
      else
        arch="$(uname -m)"
        case "$arch" in
          arm64) arch="aarch64-$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
          x86_64) arch="x86_64-$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
        esac
      fi
    fi
  fi
  
  echo -e "${YELLOW}Fetching configuration for profile ${WHITE}$base_profile${YELLOW} on ${WHITE}$arch${RESET}"
  echo
  
  format_config_yaml() {
    local config_json="$1"
    local title="$2"
    
    echo -e "${RED}$title:${RESET}"
    echo "$config_json" | jq -r \
      --arg yellow "$(echo -e "$YELLOW")" \
      --arg red "$(echo -e "$RED")" \
      --arg gray "$(echo -e "$GRAY")" \
      --arg cyan "$(echo -e "$CYAN")" \
      --arg magenta "$(echo -e "$MAGENTA")" \
      --arg white "$(echo -e "$WHITE")" \
      --arg green "$(echo -e "$GREEN")" \
      --arg blue "$(echo -e "$BLUE")" \
      --arg reset "$(echo -e "$RESET")" '
      def format_leaf_value(v):
        if v == true then $yellow + "true" + $reset
        elif v == false then $red + "false" + $reset
        elif v == null then $gray + "null" + $reset
        elif (v | type) == "string" then
          if (v | test("^/nix/store/[a-z0-9]+-")) then
            # Handle Nix store paths - show as /nix/store/NAME
            (v | gsub("^/nix/store/[a-z0-9]+-"; "") | gsub("-[0-9]+.*$"; "") as $pkg |
             $gray + "/nix/store/" + $cyan + $pkg + $reset)
          else
            $cyan + "\"" + (v | tostring) + "\"" + $reset
          end
        elif (v | type) == "number" then $magenta + (v | tostring) + $reset
        elif (v | type) == "array" then
          if length == 0 then $gray + "[]" + $reset
          else "[" + $cyan + (map(tostring) | join($reset + ", " + $cyan)) + $reset + "]"
          end
        else $white + (v | tostring) + $reset
        end;
      
      def format_nested_object(obj; depth):
        if depth > 5 then
          $white + "{...}" + $reset  # Too deep, show ellipsis
        else
          obj | to_entries[] |
          if (.value | type) == "object" then
            if (.value | keys | length) == 0 then
              (("  " * depth) + $green + .key + ":" + $reset + " " + $yellow + "true" + $reset)
            else
              (("  " * depth) + $green + .key + ":" + $reset),
              format_nested_object(.value; depth + 1)
            end
          else
            (("  " * depth) + $green + .key + ":" + $reset + " " + format_leaf_value(.value))
          end
        end;
      
      def walk_inputs(obj):
        [obj | to_entries[] as $input |
        $input.key as $input_name |
        $input.value | to_entries[] as $group |
        $group.key as $group_name |
        $group.value | to_entries[] as $module |
        $module.key as $module_name |
        $module.value as $module_config |
        if ($module_config | type) == "object" then
          if ($module_config | keys | length) == 0 then
            ($blue + $input_name + "." + $magenta + $group_name + "." + $green + $module_name + ":" + $reset + " " + $yellow + "true" + $reset)
          else
            [($blue + $input_name + "." + $magenta + $group_name + "." + $green + $module_name + ":" + $reset),
            format_nested_object($module_config; 2)] | join("\n")
          end
        else
          ($blue + $input_name + "." + $magenta + $group_name + "." + $green + $module_name + ":" + $reset + " " + format_leaf_value($module_config))
        end] as $all_modules |
        $all_modules | to_entries[] |
        if .key < (($all_modules | length) - 1) then
          if ($all_modules[.key] | test("\\n")) then
            .value + "\n"
          else
            .value
          end
        else
          .value
        end;
      
      walk_inputs(.)'
  }
  
  local full_profile="${base_profile}--${arch}"
  
  if [[ "${force_standalone:-false}" == "true" ]]; then
    if ! nix eval --json --override-input config "path:$CONFIG_DIR" ".#users.$full_profile.modules" >/dev/null 2>&1; then
      local error_output="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#users.$full_profile.modules" 2>&1)"
      echo -e "${RED}Error: Failed to evaluate standalone user modules configuration${RESET}" >&2
      echo -e "${WHITE}Details: $error_output${RESET}" >&2
      return 1
    fi
    local config_json="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#users.$full_profile.modules" 2>/dev/null)"
    format_config_yaml "$config_json" "Standalone User Modules"
  elif [[ -e /etc/NIXOS ]] || [[ "${force_nixos:-false}" == "true" ]]; then
    if ! nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$full_profile.host.modules" >/dev/null 2>&1; then
      local error_output="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$full_profile.host.modules" 2>&1)"
      echo -e "${RED}Error: Failed to evaluate host system modules configuration${RESET}" >&2
      echo -e "${WHITE}Details: $error_output${RESET}" >&2
      return 1
    fi
    local host_config_json="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$full_profile.host.modules" 2>/dev/null)"
    format_config_yaml "$host_config_json" "Host System Modules"
    echo
    if ! nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$full_profile.host.mainUser.modules" >/dev/null 2>&1; then
      local error_output="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$full_profile.host.mainUser.modules" 2>&1)"
      echo -e "${RED}Error: Failed to evaluate main user modules configuration${RESET}" >&2
      echo -e "${WHITE}Details: $error_output${RESET}" >&2
      return 1
    fi
    local user_config_json="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$full_profile.host.mainUser.modules" 2>/dev/null)"
    format_config_yaml "$user_config_json" "Main User Modules"
  else
    if ! nix eval --json --override-input config "path:$CONFIG_DIR" ".#users.$full_profile.modules" >/dev/null 2>&1; then
      local error_output="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#users.$full_profile.modules" 2>&1)"
      echo -e "${RED}Error: Failed to evaluate standalone user modules configuration${RESET}" >&2
      echo -e "${WHITE}Details: $error_output${RESET}" >&2
      return 1
    fi
    local config_json="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#users.$full_profile.modules" 2>/dev/null)"
    format_config_yaml "$config_json" "Standalone User Modules"
  fi
}


main() {
  case "${1:-help}" in
    list)
      shift
      subcommand_list "$@"
      ;;
    config)
      shift
      subcommand_config "$@"
      ;;
    info)
      shift
      subcommand_info "$@"
      ;;
    edit)
      shift
      subcommand_edit "$@"
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Error: Unknown subcommand: ${WHITE}$1${RESET}" >&2
      echo -e "Run '${WHITE}nx modules help${RESET}' for usage information." >&2
      exit 1
      ;;
  esac
}

main "$@"
