#!/usr/bin/env bash

NX_SPEC=""

load_nx_spec() {
    if [[ -n "${NX_INSTALL_PATH:-}" ]]; then
        NX_SPEC="$NX_INSTALL_PATH/nx-spec.json"
    else
        return 0
    fi

    if [[ ! -f "$NX_SPEC" ]]; then
        return 0
    fi
}

get_command_spec() {
    local cmd="$1"

    if [[ ! -f "$NX_SPEC" ]]; then
        echo "null"
        return
    fi

    jq -c ".subcommands.\"$cmd\" // null" "$NX_SPEC" 2>/dev/null || echo "null"
}

get_subcommand_spec() {
    local parent_spec="$1"
    local subcmd="$2"

    echo "$parent_spec" | jq -c ".subcommands.\"$subcmd\" // null" 2>/dev/null || echo "null"
}

get_option_spec() {
    local cmd_spec="$1"
    local opt_name="$2"

    echo "$cmd_spec" | jq -c ".options.\"$opt_name\" // null" 2>/dev/null || echo "null"
}

expand_short_option() {
    local cmd_spec="$1"
    local short_flag="$2"

    echo "$cmd_spec" | jq -r ".options | to_entries[] | select(.value.short == \"$short_flag\") | .key" 2>/dev/null || echo ""
}

has_option_argument() {
    local opt_spec="$1"
    local has_arg
    has_arg=$(echo "$opt_spec" | jq -r '.argument != null' 2>/dev/null)
    [[ "$has_arg" == "true" ]]
}

is_option_repeatable() {
    local opt_spec="$1"
    local repeatable
    repeatable=$(echo "$opt_spec" | jq -r '.repeatable // false' 2>/dev/null)
    [[ "$repeatable" == "true" ]]
}

get_option_argument_type() {
    local opt_spec="$1"
    echo "$opt_spec" | jq -r '.argument.type // "string"' 2>/dev/null
}

get_option_argument_values() {
    local opt_spec="$1"
    echo "$opt_spec" | jq -r '.argument.values // [] | join(" ")' 2>/dev/null
}

get_arguments_spec() {
    local cmd_spec="$1"
    echo "$cmd_spec" | jq -c '.arguments // []' 2>/dev/null
}

get_argument_at_index() {
    local args_spec="$1"
    local index="$2"
    echo "$args_spec" | jq -c ".[$index] // null" 2>/dev/null
}

is_argument_required() {
    local arg_spec="$1"
    local required
    required=$(echo "$arg_spec" | jq -r '.required // true' 2>/dev/null)
    [[ "$required" == "true" ]]
}

is_argument_variadic() {
    local arg_spec="$1"
    local variadic
    variadic=$(echo "$arg_spec" | jq -r '.variadic // false' 2>/dev/null)
    [[ "$variadic" == "true" ]]
}

get_argument_type() {
    local arg_spec="$1"
    echo "$arg_spec" | jq -r '.type // "string"' 2>/dev/null
}

get_argument_values() {
    local arg_spec="$1"
    echo "$arg_spec" | jq -r '.values // [] | join(" ")' 2>/dev/null
}

get_argument_name() {
    local arg_spec="$1"
    echo "$arg_spec" | jq -r '.name // ""' 2>/dev/null
}

validate_type() {
    local value="$1"
    local type="$2"
    local enum_values="$3"
    local field_name="$4"

    case "$type" in
        string)
            return 0
            ;;
        int)
            if [[ ! "$value" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}Error: ${WHITE}$field_name${RED} expected integer, got: ${WHITE}$value${RESET}" >&2
                return 1
            fi
            ;;
        filepath|dirpath)
            return 0
            ;;
        enum)
            if [[ -n "$enum_values" ]]; then
                local found=false
                for ev in $enum_values; do
                    if [[ "$value" == "$ev" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == "false" ]]; then
                    echo -e "${RED}Error: Invalid value ${WHITE}'$value'${RED} for ${WHITE}$field_name${RED}, expected one of: ${WHITE}$enum_values${RESET}" >&2
                    return 1
                fi
            fi
            ;;
        gitBranch|modulePath|nixVersion)
            return 0
            ;;
        *)
            return 0
            ;;
    esac
    return 0
}

show_top_level_help() {
    local spec_content
    local name
    local description
    local global_opts

    spec_content=$(cat "$NX_SPEC")
    name=$(echo "$spec_content" | jq -r '.name')
    description=$(echo "$spec_content" | jq -r '.description')

    echo "Usage: $name <command> [args...]"

    global_opts=$(echo "$spec_content" | jq -r '.options // {}')
    echo "$global_opts" | jq -r 'to_entries[] | "       '"$name"' --\(.key)"'

    echo
    echo "Description:"
    echo "  $description"
    echo
    echo "Commands:"
    echo

    echo "$spec_content" | python3 "$NX_INSTALL_PATH/scripts/utils/nx-help-formatter.py"

    echo "Options:"
    echo "$global_opts" | jq -r 'to_entries[] |
        {
            key: .key,
            short: .value.short,
            desc: .value.description
        } |
        "    " + (if .short then "-\(.short), " else "    " end) + "--\(.key)" +
        (if (2 + (.key | length)) < 18 then
            (" " * (18 - (2 + (.key | length)))) + .desc
         else
            "\n" + (" " * 26) + .desc
         end)
    '
}

show_command_help() {
    local cmd_path="$1"

    load_nx_spec

    if [[ ! -f "$NX_SPEC" ]]; then
        echo -e "${RED}Help not available in local development version${RESET}" >&2
        exit 1
    fi

    if [[ -z "$cmd_path" ]]; then
        show_top_level_help
        exit 0
    fi

    local cmd_parts
    IFS=' ' read -ra cmd_parts <<< "$cmd_path"
    local cmd_spec
    cmd_spec=$(get_command_spec "${cmd_parts[0]}")

    if [[ "$cmd_spec" == "null" ]]; then
        show_top_level_help
        exit 0
    fi

    for ((i=1; i<${#cmd_parts[@]}; i++)); do
        cmd_spec=$(get_subcommand_spec "$cmd_spec" "${cmd_parts[$i]}")
        if [[ "$cmd_spec" == "null" ]]; then
            echo -e "${RED}Error: Unknown subcommand${RESET}" >&2
            exit 1
        fi
    done

    local description
    local args_spec
    local arg_count

    description=$(echo "$cmd_spec" | jq -r '.description // ""')

    echo -n "Usage: nx $cmd_path"

    args_spec=$(echo "$cmd_spec" | jq -c '.arguments // []')
    arg_count=$(echo "$args_spec" | jq 'length')

    for ((i=0; i<arg_count; i++)); do
        local arg_spec
        local arg_name
        local required
        local variadic

        arg_spec=$(echo "$args_spec" | jq -c ".[$i]")
        arg_name=$(echo "$arg_spec" | jq -r '.name')
        required=$(echo "$arg_spec" | jq -r '.required // true')
        variadic=$(echo "$arg_spec" | jq -r '.variadic // false')

        if [[ "$variadic" == "true" ]] || [[ "$required" == "true" ]]; then
            echo -n " <$arg_name>"
        else
            echo -n " [$arg_name]"
        fi
    done

    local has_opts
    has_opts=$(echo "$cmd_spec" | jq -r '.options | length > 0')
    if [[ "$has_opts" == "true" ]]; then
        echo " [options...]"
    else
        echo
    fi

    echo
    echo "Description:"
    echo "  $description"

    local subcommands
    local has_subs

    subcommands=$(echo "$cmd_spec" | jq -r '.subcommands // {}')
    has_subs=$(echo "$subcommands" | jq 'length > 0')

    if [[ "$has_subs" == "true" ]]; then
        echo
        echo "Subcommands:"
        echo "$subcommands" | jq -r 'to_entries[] |
            {
                name: .key,
                desc: .value.description,
                args: .value.arguments // []
            } |
            (if (.args | length) > 0 then
                " " + ([.args[] | if .variadic then "<\(.name)>" elif (.required // true) then "<\(.name)>" else "[\(.name)]" end] | join(" "))
             else
                ""
             end) as $args_str |
            ((.name | length) + ($args_str | length)) as $full_len |
            "    " + .name + $args_str +
            (if $full_len < 22 then
                (" " * (22 - $full_len)) + .desc
             else
                "\n" + (" " * 26) + .desc
             end)
        '
    fi

    local options
    local has_opts_section

    options=$(echo "$cmd_spec" | jq -r '.options // {}')
    has_opts_section=$(echo "$options" | jq 'length > 0')

    if [[ "$has_opts_section" == "true" ]]; then
        echo
        echo "Options:"
        echo "$options" | jq -r 'to_entries[] |
            {
                key: .key,
                short: .value.short,
                arg: .value.argument,
                desc: .value.description
            } |
            "    " +
            (if .short then "-\(.short), " else "    " end) +
            "--\(.key)" +
            (if .arg then " <\(.arg.name)>" else "" end) +
            (if (2 + (.key | length) + (if .arg then (.arg.name | length) + 3 else 0 end)) < 18 then
                (" " * (18 - (2 + (.key | length) + (if .arg then (.arg.name | length) + 3 else 0 end)))) + .desc
             else
                "\n" + (" " * 26) + .desc
             end)
        '
    fi

    exit 0
}

validate_command_recursive() {
    local cmd_spec="$1"
    local cmd_path="$2"
    shift 2
    local args=("$@")

    if [[ ${#args[@]} -gt 0 ]] && [[ "${args[0]}" != -* ]]; then
        local subcommand_names
        subcommand_names=$(echo "$cmd_spec" | jq -r '.subcommands // {} | keys[]' 2>/dev/null || echo "")

        if [[ -n "$subcommand_names" ]]; then
            while IFS= read -r subcmd; do
                if [[ -n "$subcmd" ]] && [[ "${args[0]}" == "$subcmd" ]]; then
                    local sub_spec
                    sub_spec=$(get_subcommand_spec "$cmd_spec" "$subcmd")
                    local remaining_args=("${args[@]:1}")
                    validate_command_recursive "$sub_spec" "$cmd_path $subcmd" ${remaining_args[@]+"${remaining_args[@]}"}
                    return $?
                fi
            done <<< "$subcommand_names"
        fi
    fi

    local positional_args=()
    local seen_options=()
    local end_of_options=false

    while [[ ${#args[@]} -gt 0 ]]; do
        local arg="${args[0]}"

        if [[ "$arg" == "--" ]]; then
            args=("${args[@]:1}")
            positional_args+=(${args[@]+"${args[@]}"})
            break
        fi

        if [[ "$end_of_options" == "false" ]] && [[ "$arg" == --* ]]; then
            local opt_name="${arg#--}"
            local opt_spec
            opt_spec=$(get_option_spec "$cmd_spec" "$opt_name")

            if [[ "$opt_spec" == "null" ]]; then
                echo -e "${RED}Error: Unknown option ${WHITE}--$opt_name${RED} for command ${WHITE}$cmd_path${RESET}" >&2
                return 1
            fi

            if ! is_option_repeatable "$opt_spec"; then
                for seen_opt in ${seen_options[@]+"${seen_options[@]}"}; do
                    if [[ "$seen_opt" == "$opt_name" ]]; then
                        echo -e "${RED}Error: Option ${WHITE}--$opt_name${RED} cannot be repeated${RESET}" >&2
                        return 1
                    fi
                done
            fi
            seen_options+=("$opt_name")

            if has_option_argument "$opt_spec"; then
                if [[ ${#args[@]} -lt 2 ]]; then
                    echo -e "${RED}Error: Option ${WHITE}--$opt_name${RED} requires an argument${RESET}" >&2
                    return 1
                fi

                local opt_value="${args[1]}"
                local opt_type
                local opt_values

                opt_type=$(get_option_argument_type "$opt_spec")
                opt_values=$(get_option_argument_values "$opt_spec")

                if ! validate_type "$opt_value" "$opt_type" "$opt_values" "--$opt_name"; then
                    return 1
                fi

                args=("${args[@]:2}")
            else
                args=("${args[@]:1}")
            fi
        elif [[ "$end_of_options" == "false" ]] && [[ "$arg" == -* ]] && [[ "$arg" != "-" ]]; then
            local short_flag="${arg#-}"
            local long_name
            long_name=$(expand_short_option "$cmd_spec" "$short_flag")

            if [[ -z "$long_name" ]]; then
                echo -e "${RED}Error: Unknown short option ${WHITE}-$short_flag${RED} for command ${WHITE}$cmd_path${RESET}" >&2
                return 1
            fi

            args[0]="--$long_name"
        else
            positional_args+=("$arg")
            args=("${args[@]:1}")
        fi
    done

    local subcommand_names
    subcommand_names=$(echo "$cmd_spec" | jq -r '.subcommands // {} | keys[]' 2>/dev/null || echo "")

    local args_spec
    local arg_index=0
    local positional_index=0

    args_spec=$(get_arguments_spec "$cmd_spec")

    while true; do
        local arg_spec
        arg_spec=$(get_argument_at_index "$args_spec" "$arg_index")

        if [[ "$arg_spec" == "null" ]]; then
            break
        fi

        local arg_name
        arg_name=$(get_argument_name "$arg_spec")

        if is_argument_variadic "$arg_spec"; then
            while [[ $positional_index -lt ${#positional_args[@]} ]]; do
                local arg_value="${positional_args[$positional_index]}"
                local arg_type
                local arg_values

                arg_type=$(get_argument_type "$arg_spec")
                arg_values=$(get_argument_values "$arg_spec")

                if ! validate_type "$arg_value" "$arg_type" "$arg_values" "$arg_name"; then
                    return 1
                fi

                positional_index=$((positional_index + 1))
            done
            break
        else
            if [[ $positional_index -lt ${#positional_args[@]} ]]; then
                local arg_value="${positional_args[$positional_index]}"
                local arg_type
                local arg_values

                arg_type=$(get_argument_type "$arg_spec")
                arg_values=$(get_argument_values "$arg_spec")

                if ! validate_type "$arg_value" "$arg_type" "$arg_values" "$arg_name"; then
                    return 1
                fi

                positional_index=$((positional_index + 1))
            elif is_argument_required "$arg_spec"; then
                echo -e "${RED}Error: Missing required argument ${WHITE}<$arg_name>${RESET}" >&2
                return 1
            fi
        fi

        arg_index=$((arg_index + 1))
    done

    if [[ $positional_index -lt ${#positional_args[@]} ]]; then
        local first_remaining="${positional_args[$positional_index]}"

        local found_subcmd=""
        if [[ -n "$subcommand_names" ]]; then
            while IFS= read -r subcmd; do
                if [[ -n "$subcmd" ]] && [[ "$first_remaining" == "$subcmd" ]]; then
                    found_subcmd="$subcmd"
                    break
                fi
            done <<< "$subcommand_names"
        fi

        if [[ -n "$found_subcmd" ]]; then
            local sub_spec
            sub_spec=$(get_subcommand_spec "$cmd_spec" "$found_subcmd")

            local remaining_args=(${positional_args[@]+"${positional_args[@]:$((positional_index + 1))}"})
            validate_command_recursive "$sub_spec" "$cmd_path $found_subcmd" ${remaining_args[@]+"${remaining_args[@]}"}
            return $?
        else
            local extra_args="${positional_args[*]:$positional_index}"
            echo -e "${RED}Error: Unexpected arguments: ${WHITE}$extra_args${RESET}" >&2
            return 1
        fi
    fi

    return 0
}

validate_command() {
    local cmd="$1"
    shift
    local args=("$@")

    load_nx_spec

    if [[ ! -f "$NX_SPEC" ]]; then
        return 0
    fi

    local cmd_spec
    cmd_spec=$(get_command_spec "$cmd")

    if [[ "$cmd_spec" == "null" ]]; then
        echo -e "${RED}Error: Unknown command ${WHITE}'$cmd'${RESET}" >&2
        echo >&2
        echo -e "${CYAN}Run '${WHITE}nx --help${CYAN}' to see available commands.${RESET}" >&2
        return 1
    fi

    validate_command_recursive "$cmd_spec" "$cmd" ${args[@]+"${args[@]}"}
}
