#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "modules"
check_deployment_conflicts "modules"

NX_OVERRIDE_ARGS=()
if [[ -n "${NXCORE_DIR:-}" && "${NX_DEPLOYMENT_MODE:-develop}" == "develop" ]]; then
    NX_OVERRIDE_ARGS=("--override-input" "core" "path:$NXCORE_DIR")
fi

get_config_path() {
  local profile="$1"
  local context="$2"

  if [[ "$context" == "nixos" ]]; then
    echo ".#nixosConfigurations.${profile}.config"
  else
    echo ".#homeConfigurations.${profile}.config"
  fi
}

determine_context() {
  if [[ "${force_nixos:-false}" == "true" ]]; then
    echo "nixos"
  elif [[ "${force_standalone:-false}" == "true" ]]; then
    echo "home"
  elif [[ -e /etc/NIXOS ]]; then
    echo "nixos"
  else
    echo "home"
  fi
}

subcommand_list() {
  local show_active_only=false
  local show_inactive_only=false
  local override_profile=""
  local override_arch=""

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
        [[ $# -lt 2 ]] && { echo -e "${RED}Error: --profile requires a profile name${RESET}" >&2; exit 1; }
        override_profile="$2"
        shift 2
        ;;
      --arch)
        [[ $# -lt 2 ]] && { echo -e "${RED}Error: --arch requires an architecture${RESET}" >&2; exit 1; }
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
        echo -e "Usage: ${WHITE}nx modules list [--active] [--inactive] [--profile <profile>] [--arch <arch>] [--nixos] [--standalone]${RESET}" >&2
        exit 1
        ;;
    esac
  done

  [[ "$show_active_only" == "true" && "$show_inactive_only" == "true" ]] && {
    echo -e "${RED}Error: --active and --inactive cannot be used together${RESET}" >&2
    exit 1
  }

  [[ "${force_nixos:-false}" == "true" && "${force_standalone:-false}" == "true" ]] && {
    echo -e "${RED}Error: --nixos and --standalone cannot be used together${RESET}" >&2
    exit 1
  }

  local base_profile
  if [[ -n "$override_profile" ]]; then
    base_profile="$override_profile"
  elif [[ -e .nx-profile.conf ]]; then
    base_profile="$(cat .nx-profile.conf)"
  elif [[ -e /etc/nixos ]]; then
    base_profile="$HOSTNAME"
  else
    base_profile="$USER"
  fi

  local profile
  if [[ -n "$override_arch" ]]; then
    profile="$(construct_profile_name "$base_profile" "$override_arch")"
  else
    profile="$(construct_profile_name "$base_profile")"
  fi

  local context
  context="$(determine_context)"

  if [[ -n "$override_arch" ]]; then
    if [[ "$context" == "nixos" && ! "$override_arch" =~ -linux$ ]]; then
      echo -e "${RED}Error: NixOS profiles only support Linux architectures (x86_64-linux, aarch64-linux)${RESET}" >&2
      echo -e "${YELLOW}Hint: Use --profile to specify a home-manager profile, or use --standalone flag${RESET}" >&2
      exit 1
    fi
  fi

  local config_path
  config_path="$(get_config_path "$profile" "$context")"

  echo -e "${YELLOW}Fetching modules from config.nx...${RESET}"
  echo

  local modules_json
  # shellcheck disable=SC2016
  modules_json="$(nix eval --json "${NX_OVERRIDE_ARGS[@]}" "${config_path}.nx" --apply '
    nx:
    let
      moduleInputs = builtins.attrNames nx;

      filterAttrs = pred: set:
        builtins.listToAttrs (
          builtins.filter (item: pred item.name item.value) (
            builtins.map (name: { name = name; value = set.${name}; }) (builtins.attrNames set)
          )
        );

      collectModules = inputs:
        builtins.foldl'\'' (acc: inputName:
          let
            inputData = nx.${inputName} or {};
            groups = if builtins.isAttrs inputData then builtins.attrNames inputData else [];
          in
          acc // {
            ${inputName} = builtins.foldl'\'' (gAcc: groupName:
              let
                groupData = inputData.${groupName} or {};
                modules = if builtins.isAttrs groupData
                  then builtins.attrNames (filterAttrs (n: v: builtins.isAttrs v && v ? enable) groupData)
                  else [];
              in
              if modules == [] then gAcc
              else gAcc // {
                ${groupName} = builtins.foldl'\'' (mAcc: moduleName:
                  let
                    moduleData = groupData.${moduleName};
                  in
                  mAcc // {
                    ${moduleName} = {
                      enable = moduleData.enable or false;
                      description = moduleData.meta.description or "No description";
                    };
                  }
                ) {} modules;
              }
            ) {} groups;
          }
        ) {} inputs;
    in
    collectModules moduleInputs
  ' 2>/dev/null || {
    echo -e "${YELLOW}Main eval failed, running diagnostic on full nx tree...${RESET}" >&2
    # shellcheck disable=SC2016
    nix eval --show-trace --json "${NX_OVERRIDE_ARGS[@]}" "${config_path}.nx" --apply '
      nx: let
        sanitize = v:
          if builtins.isFunction v then "<function>"
          else if builtins.isAttrs v then
            if v ? __functor then "<function>"
            else builtins.mapAttrs (n: _: sanitize v.${n}) (builtins.removeAttrs v ["_module"])
          else if builtins.isList v then map sanitize v
          else v;
      in sanitize nx
    ' || echo '{}'
  })"

  if [[ "$modules_json" == "{}" ]]; then
    echo -e "${RED}Error: Failed to fetch modules from config${RESET}" >&2
    exit 1
  fi

  local all_modules=()

  while IFS='|' read -r module_id is_active description; do
    [[ -z "$module_id" ]] && continue

    if [[ "$show_active_only" == "true" && "$is_active" != "true" ]]; then
      continue
    fi
    if [[ "$show_inactive_only" == "true" && "$is_active" == "true" ]]; then
      continue
    fi

    local status_indicator=""
    if [[ "$is_active" == "true" ]]; then
      status_indicator="\033[1;32m●\033[0m "
    else
      status_indicator="\033[1;31m○\033[0m "
    fi

    local formatted_line
    formatted_line="$(printf "  %b\033[1;37m%-40s\033[0m %s" "$status_indicator" "$module_id" "$description")"
    all_modules+=("$formatted_line")
  done < <(echo "$modules_json" | jq -r '
    to_entries[] as $input |
    $input.key as $input_name |
    $input.value | to_entries[] as $group |
    $group.key as $group_name |
    $group.value | to_entries[] as $module |
    $module.key as $module_name |
    $module.value as $module_data |
    "\($input_name).\($group_name).\($module_name)|\($module_data.enable)|\($module_data.description)"
  ')

  if [[ ${#all_modules[@]} -gt 0 ]]; then
    echo -e "${RED}Modules:${RESET}"
    printf "%s\n" "${all_modules[@]}"
  else
    echo -e "${RED}Error: No modules found matching the specified criteria${RESET}" >&2
    exit 1
  fi
}

subcommand_info() {
  local override_profile=""
  local override_arch=""
  local module_id=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --profile)
        [[ $# -lt 2 ]] && { echo -e "${RED}Error: --profile requires a profile name${RESET}" >&2; exit 1; }
        override_profile="$2"
        shift 2
        ;;
      --arch)
        [[ $# -lt 2 ]] && { echo -e "${RED}Error: --arch requires an architecture${RESET}" >&2; exit 1; }
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
      -*)
        echo -e "${RED}Error: Unknown option: ${WHITE}$1${RESET}" >&2
        echo -e "Usage: ${WHITE}nx modules info [--profile <profile>] [--arch <arch>] [--nixos] [--standalone] INPUT.GROUP.MODULE${RESET}" >&2
        exit 1
        ;;
      *)
        [[ -n "$module_id" ]] && { echo -e "${RED}Error: Unexpected argument: ${WHITE}$1${RESET}" >&2; exit 1; }
        module_id="$1"
        shift
        ;;
    esac
  done

  [[ -z "$module_id" ]] && {
    echo -e "${RED}Error: MODULE argument required${RESET}" >&2
    echo -e "Usage: ${WHITE}nx modules info [--profile <profile>] [--arch <arch>] [--nixos] [--standalone] INPUT.GROUP.MODULE${RESET}" >&2
    exit 1
  }

  [[ ! "$module_id" =~ ^[^.]+\.[^.]+\.[^.]+$ ]] && {
    echo -e "${RED}Error: Invalid module format. Expected: INPUT.GROUP.MODULE${RESET}" >&2
    exit 1
  }

  [[ "${force_nixos:-false}" == "true" && "${force_standalone:-false}" == "true" ]] && {
    echo -e "${RED}Error: --nixos and --standalone cannot be used together${RESET}" >&2
    exit 1
  }

  local input_name="${module_id%%.*}"
  local rest="${module_id#*.}"
  local group_name="${rest%%.*}"
  local module_name="${rest#*.}"

  local profile_path
  profile_path="$(retrieve_active_profile_path)"
  local base_path
  if [[ "$input_name" == "config" ]]; then
    base_path="$CONFIG_DIR"
  elif [[ "$input_name" == "profile" ]]; then
    base_path="$profile_path"
  else
    base_path="$NXCORE_DIR/src/$input_name"
  fi

  local module_file
  module_file="$(module_file_path "$base_path" "$input_name" "$group_name" "$module_name")"
  if [[ ! -f "$module_file" ]]; then
    echo -e "${RED}Error: Module file not found: ${WHITE}$module_file${RESET}" >&2
    echo -e "${YELLOW}Hint: Check the module path for typos. Expected format: INPUT.GROUP.MODULE${RESET}" >&2
    exit 1
  fi

  local base_profile
  if [[ -n "$override_profile" ]]; then
    base_profile="$override_profile"
  elif [[ -e .nx-profile.conf ]]; then
    base_profile="$(cat .nx-profile.conf)"
  elif [[ -e /etc/nixos ]]; then
    base_profile="$HOSTNAME"
  else
    base_profile="$USER"
  fi

  local profile
  if [[ -n "$override_arch" ]]; then
    profile="$(construct_profile_name "$base_profile" "$override_arch")"
  else
    profile="$(construct_profile_name "$base_profile")"
  fi

  local context
  context="$(determine_context)"

  if [[ -n "$override_arch" ]]; then
    if [[ "$context" == "nixos" && ! "$override_arch" =~ -linux$ ]]; then
      echo -e "${RED}Error: NixOS profiles only support Linux architectures (x86_64-linux, aarch64-linux)${RESET}" >&2
      echo -e "${YELLOW}Hint: Use --profile to specify a home-manager profile, or use --standalone flag${RESET}" >&2
      exit 1
    fi
  fi

  local config_path
  config_path="$(get_config_path "$profile" "$context")"

  echo -e "${YELLOW}Fetching module information from config.nx...${RESET}"
  echo

  local module_info
  # shellcheck disable=SC2016
  module_info="$(nix eval --json "${NX_OVERRIDE_ARGS[@]}" "${config_path}.nx.${input_name}.${group_name}.${module_name}" --apply '
    moduleData:
    let
      sanitize = v:
        if builtins.isFunction v then "<function>"
        else if builtins.isAttrs v then
          if v ? __functor then "<function>"
          else builtins.mapAttrs (n: _: sanitize v.${n}) (builtins.removeAttrs v ["_module"])
        else if builtins.isList v then map sanitize v
        else v;
    in
    sanitize moduleData
  ' 2>/dev/null || {
    echo -e "${YELLOW}Main eval failed, running diagnostic on full nx tree...${RESET}" >&2
    # shellcheck disable=SC2016
    nix eval --show-trace --json "${NX_OVERRIDE_ARGS[@]}" "${config_path}.nx" --apply '
      nx: let
        sanitize = v:
          if builtins.isFunction v then "<function>"
          else if builtins.isAttrs v then
            if v ? __functor then "<function>"
            else builtins.mapAttrs (n: _: sanitize v.${n}) (builtins.removeAttrs v ["_module"])
          else if builtins.isList v then map sanitize v
          else v;
      in sanitize nx
    ' || echo "null"
  })"

  [[ "$module_info" == "null" ]] && {
    echo -e "${RED}Error: Module not found: ${WHITE}$module_id${RESET}" >&2
    exit 1
  }

  echo
  echo -e "${GREEN}Module Information: ${WHITE}$module_id${RESET}"
  echo

  local enable
  enable=$(echo "$module_info" | jq -r '.enable // false')
  local description
  description=$(echo "$module_info" | jq -r '.meta.description // "No description"')
  local meta_input
  meta_input=$(echo "$module_info" | jq -r '.meta.input // "unknown"')
  local meta_group
  meta_group=$(echo "$module_info" | jq -r '.meta.group // "unknown"')
  local meta_name
  meta_name=$(echo "$module_info" | jq -r '.meta.name // "unknown"')

  local module_path
  if is_modules_only_input "$input_name"; then
    module_path="src/${input_name}/${group_name}/${module_name}.nix"
  else
    module_path="src/${input_name}/modules/${group_name}/${module_name}.nix"
  fi

  echo -e "  ${GREEN}name:${RESET} ${RED}\"$meta_name\"${RESET}"
  echo -e "  ${GREEN}description:${RESET} ${RED}\"$description\"${RESET}"
  echo -e "  ${GREEN}group:${RESET} ${RED}\"$meta_group\"${RESET}"
  echo -e "  ${GREEN}input:${RESET} ${RED}\"$meta_input\"${RESET}"
  echo -e "  ${GREEN}path:${RESET} ${RED}\"$module_path\"${RESET}"
  echo -e "  ${GREEN}enable:${RESET} ${YELLOW}$enable${RESET}"

  local remaining_options
  remaining_options=$(echo "$module_info" | jq 'del(.enable, .meta)')
  local has_options
  has_options=$(echo "$remaining_options" | jq 'keys | length > 0')

  if [[ "$has_options" == "true" ]]; then
    echo
    echo -e "  ${GREEN}options:${RESET}"
    echo "$remaining_options" | jq -r \
      --arg green "$(echo -e "$GREEN")" \
      --arg yellow "$(echo -e "$YELLOW")" \
      --arg red "$(echo -e "$RED")" \
      --arg cyan "$(echo -e "$CYAN")" \
      --arg magenta "$(echo -e "$MAGENTA")" \
      --arg gray "$(echo -e "$GRAY")" \
      --arg reset "$(echo -e "$RESET")" '
      def format_value(v):
        if v == true then $yellow + "true" + $reset
        elif v == false then $red + "false" + $reset
        elif v == null then $gray + "null" + $reset
        elif v == "<function>" then $gray + "<function>" + $reset
        elif (v | type) == "string" then $cyan + "\"" + v + "\"" + $reset
        elif (v | type) == "number" then $magenta + (v | tostring) + $reset
        elif (v | type) == "array" then
          if length == 0 then $gray + "[]" + $reset
          else "[" + (map(tostring) | join(", ")) + "]"
          end
        else (v | tostring)
        end;

      def format_nested(obj; depth):
        obj | to_entries[] |
        if (.value | type) == "object" then
          if (.value | keys | length) == 0 then
            ("    " * depth) + $green + .key + ":" + $reset + " " + $yellow + "{}" + $reset
          else
            [("    " * depth) + $green + .key + ":" + $reset,
             format_nested(.value; depth + 1)] | join("\n")
          end
        else
          ("    " * depth) + $green + .key + ":" + $reset + " " + format_value(.value)
        end;

      format_nested(.; 1)'
  fi
}

subcommand_edit() {
  [[ $# -eq 0 ]] && {
    echo -e "${RED}Error: MODULE argument required${RESET}" >&2
    echo -e "Usage: ${WHITE}nx modules edit INPUT.GROUP.MODULE${RESET}" >&2
    exit 1
  }

  local module_id="$1"
  [[ ! "$module_id" =~ ^[^.]+\.[^.]+\.[^.]+$ ]] && {
    echo -e "${RED}Error: Invalid module format. Expected: INPUT.GROUP.MODULE${RESET}" >&2
    exit 1
  }

  local input_name="${module_id%%.*}"
  local rest="${module_id#*.}"
  local group_name="${rest%%.*}"
  local module_name="${rest#*.}"

  local core_inputs=("common" "linux" "darwin" "groups" "build" "config" "profile" "themes" "overlays")
  local input_allowed=false
  for allowed_input in "${core_inputs[@]}"; do
    [[ "$input_name" == "$allowed_input" ]] && { input_allowed=true; break; }
  done

  [[ "$input_allowed" != "true" ]] && {
    echo -e "${RED}Error: Module editing only allowed for core inputs: ${WHITE}${core_inputs[*]}${RESET}" >&2
    exit 1
  }

  local profile_path
  profile_path="$(retrieve_active_profile_path)"
  local base_path
  if [[ "$input_name" == "config" ]]; then
    base_path="$CONFIG_DIR"
  elif [[ "$input_name" == "profile" ]]; then
    base_path="$profile_path"
  else
    base_path="$NXCORE_DIR/src/$input_name"
  fi

  local target_file
  target_file="$(module_file_path "$base_path" "$input_name" "$group_name" "$module_name")"

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
        [[ $# -lt 2 ]] && { echo -e "${RED}Error: --profile requires a profile name${RESET}" >&2; exit 1; }
        override_profile="$2"
        shift 2
        ;;
      --arch)
        [[ $# -lt 2 ]] && { echo -e "${RED}Error: --arch requires an architecture${RESET}" >&2; exit 1; }
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

  [[ "${force_nixos:-false}" == "true" && "${force_standalone:-false}" == "true" ]] && {
    echo -e "${RED}Error: --nixos and --standalone cannot be used together${RESET}" >&2
    exit 1
  }

  local base_profile
  if [[ -n "$override_profile" ]]; then
    base_profile="$override_profile"
  elif [[ -e .nx-profile.conf ]]; then
    base_profile="$(cat .nx-profile.conf)"
  elif [[ -e /etc/nixos ]]; then
    base_profile="$HOSTNAME"
  else
    base_profile="$USER"
  fi

  local profile
  if [[ -n "$override_arch" ]]; then
    profile="$(construct_profile_name "$base_profile" "$override_arch")"
  else
    profile="$(construct_profile_name "$base_profile")"
  fi

  local context
  context="$(determine_context)"

  if [[ -n "$override_arch" ]]; then
    if [[ "$context" == "nixos" && ! "$override_arch" =~ -linux$ ]]; then
      echo -e "${RED}Error: NixOS profiles only support Linux architectures (x86_64-linux, aarch64-linux)${RESET}" >&2
      echo -e "${YELLOW}Hint: Use --profile to specify a home-manager profile, or use --standalone flag${RESET}" >&2
      exit 1
    fi
  fi

  local config_path
  config_path="$(get_config_path "$profile" "$context")"

  echo -e "${YELLOW}Fetching configuration for profile ${WHITE}$profile${RESET}"
  echo

  local config_json
  # shellcheck disable=SC2016
  config_json="$(nix eval --json "${NX_OVERRIDE_ARGS[@]}" "${config_path}.nx" --apply '
    nx:
    let
      moduleInputs = builtins.attrNames nx;

      filterAttrs = pred: set:
        builtins.listToAttrs (
          builtins.filter (item: pred item.name item.value) (
            builtins.map (name: { name = name; value = set.${name}; }) (builtins.attrNames set)
          )
        );

      sanitize = v:
        if builtins.isFunction v then "<function>"
        else if builtins.isAttrs v then
          if v ? __functor then "<function>"
          else builtins.mapAttrs (n: _: sanitize v.${n}) (builtins.removeAttrs v ["_module"])
        else if builtins.isList v then map sanitize v
        else v;

      filterEnabled = input:
        if builtins.isAttrs input then
          builtins.mapAttrs (groupName: groupData:
            if builtins.isAttrs groupData then
              builtins.mapAttrs (moduleName: moduleData:
                sanitize (builtins.removeAttrs moduleData [ "enable" "meta" ])
              ) (filterAttrs (n: v: builtins.isAttrs v && (v.enable or false) == true) groupData)
            else {}
          ) input
        else {};

      collectEnabled = inputs:
        builtins.foldl'\'' (acc: inputName:
          let
            inputData = nx.${inputName} or {};
            filteredInput = filterEnabled inputData;
          in
          if filteredInput == {} then acc else acc // { ${inputName} = filteredInput; }
        ) {} inputs;
    in
    collectEnabled moduleInputs
  ' 2>/dev/null || {
    echo -e "${YELLOW}Main eval failed, running diagnostic on full nx tree...${RESET}" >&2
    # shellcheck disable=SC2016
    nix eval --show-trace --json "${NX_OVERRIDE_ARGS[@]}" "${config_path}.nx" --apply '
      nx: let
        sanitize = v:
          if builtins.isFunction v then "<function>"
          else if builtins.isAttrs v then
            if v ? __functor then "<function>"
            else builtins.mapAttrs (n: _: sanitize v.${n}) (builtins.removeAttrs v ["_module"])
          else if builtins.isList v then map sanitize v
          else v;
      in sanitize nx
    ' || echo '{}'
  })"

  [[ "$config_json" == "{}" ]] && {
    echo -e "${RED}Error: Failed to fetch module configuration${RESET}" >&2
    exit 1
  }

  echo -e "${RED}Modules:${RESET}"
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
      elif (v | type) == "string" then $cyan + "\"" + (v | tostring) + "\"" + $reset
      elif (v | type) == "number" then $magenta + (v | tostring) + $reset
      elif (v | type) == "array" then
        if length == 0 then $gray + "[]" + $reset
        else "[" + $cyan + (map(tostring) | join($reset + ", " + $cyan)) + $reset + "]"
        end
      else $white + (v | tostring) + $reset
      end;

    def format_nested(obj; depth):
      if depth > 5 then $white + "{...}" + $reset
      else
        obj | to_entries[] |
        if (.value | type) == "object" then
          if (.value | keys | length) == 0 then
            (("  " * depth) + $green + .key + ":" + $reset + " " + $yellow + "{}" + $reset)
          else
            (("  " * depth) + $green + .key + ":" + $reset),
            format_nested(.value; depth + 1)
          end
        else
          (("  " * depth) + $green + .key + ":" + $reset + " " + format_leaf_value(.value))
        end
      end;

    to_entries[] as $input |
    $input.key as $input_name |
    $input.value | to_entries[] as $group |
    $group.key as $group_name |
    $group.value | to_entries[] as $module |
    $module.key as $module_name |
    $module.value as $module_config |
    if ($module_config | type) == "object" and ($module_config | keys | length) > 0 then
      [($blue + $input_name + "." + $magenta + $group_name + "." + $green + $module_name + ":" + $reset),
      format_nested($module_config; 2)] | join("\n")
    else
      ($blue + $input_name + "." + $magenta + $group_name + "." + $green + $module_name + $reset)
    end'
}

main() {
  case "${1:-}" in
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
    "")
      echo -e "${RED}Error: Subcommand required${RESET}" >&2
      echo -e "Run '${WHITE}nx modules --help${RESET}' for usage information." >&2
      exit 1
      ;;
    *)
      echo -e "${RED}Error: Unknown subcommand: ${WHITE}$1${RESET}" >&2
      echo -e "Run '${WHITE}nx modules --help${RESET}' for usage information." >&2
      exit 1
      ;;
  esac
}

main "$@"
