_complete_nx() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local commands="profile sync build gc update dry test boot rollback news config core format exec log head diff diffc status commit pull push add addp stash impermanence spec modules eval"
    
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${commands} --help --version" -- "${cur}"))
    elif [[ ${COMP_CWORD} -eq 2 ]]; then
        case "$prev" in
            profile)
                COMPREPLY=($(compgen -W "user edit select reset help" -- "${cur}"))
                ;;
            build)
                COMPREPLY=($(compgen -W "--timeout --dry-run --offline" -- "${cur}"))
                ;;
            sync|dry|test|boot)
                COMPREPLY=($(compgen -W "--offline --show-trace" -- "${cur}"))
                ;;
            log|head|diff|diffc|status|commit|pull|push|add|addp|stash)
                COMPREPLY=($(compgen -W "--only-core --only-config" -- "${cur}"))
                ;;
            impermanence)
                COMPREPLY=($(compgen -W "check logs help" -- "${cur}"))
                ;;
            spec)
                COMPREPLY=($(compgen -W "--home list switch reset" -- "${cur}"))
                ;;
            modules)
                COMPREPLY=($(compgen -W "list config info edit create help" -- "${cur}"))
                ;;
        esac
    elif [[ ${COMP_CWORD} -eq 3 ]]; then
        case "${COMP_WORDS[1]}" in
            profile)
                case "$prev" in
                    user)
                        COMPREPLY=($(compgen -W "edit" -- "${cur}"))
                        ;;
                    select)
                        COMPREPLY=()
                        ;;
                esac
                ;;
            build)
                if [[ "$prev" == "--timeout" ]]; then
                    COMPREPLY=()
                fi
                ;;
            impermanence)
                case "$prev" in
                    check)
                        COMPREPLY=($(compgen -W "--home --system --filter" -- "${cur}"))
                        ;;
                esac
                ;;
            spec)
                if [[ "$prev" == "switch" ]]; then
                    COMPREPLY=()
                fi
                ;;
            modules)
                case "$prev" in
                    list)
                        COMPREPLY=($(compgen -W "--active --inactive --profile --nixos --standalone" -- "${cur}"))
                        ;;
                    config)
                        COMPREPLY=($(compgen -W "--profile --arch --nixos --standalone" -- "${cur}"))
                        ;;
                    info|edit|create)
                        COMPREPLY=()
                        ;;
                esac
                ;;
        esac
    elif [[ ${COMP_CWORD} -eq 4 ]] && [[ "${COMP_WORDS[1]}" == "impermanence" ]] && [[ "${COMP_WORDS[2]}" == "check" ]]; then
        case "$prev" in
            --filter)
                COMPREPLY=()
                ;;
            *)
                COMPREPLY=($(compgen -W "--home --system --filter" -- "${cur}"))
                ;;
        esac
    fi
}

complete -F _complete_nx nx
