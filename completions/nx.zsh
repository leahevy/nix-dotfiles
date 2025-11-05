_nx() {
    local context state line
    
    _arguments \
        '(--help)--help[Show help message]' \
        '(--version)--version[Show version information]' \
        '1: :->commands' \
        '*::arg:->args'
    
    case $state in
        commands)
            local commands=(
                'profile:Configure to use profile'
                'sync:Sync/deploy the system state'
                'build:Test build configuration without deploying'
                'gc:Run the garbage collection'
                'update:Update the flake in git (without switching)'
                'brew:Sync Homebrew packages (Darwin only)'
                'dry:Test configuration without deploying (NixOS only)'
                'test:Activate without adding to bootloader (NixOS only)'
                'boot:Add to bootloader without switching (NixOS only)'
                'rollback:Rollback to previous configuration (NixOS only)'
                'news:Show recent news (Home Manager only)'
                'config:Open a shell in the config directory'
                'core:Open a shell in the core directory'
                'format:Format directories with treefmt'
                'exec:Run any command in the directory'
                'log:Run git log command'
                'head:Run git show HEAD command'
                'diff:Run git diff command'
                'diffc:Run git diff command with --cached'
                'status:Run git status command'
                'commit:Run git commit command'
                'pull:Run git pull command'
                'push:Run git push command'
                'add:Run git add command'
                'addp:Run git add command with --patch'
                'stash:Run git stash command'
                'impermanence:Manage ephemeral root filesystems'
                'spec:Manage specializations'
                'modules:Manage and inspect NX modules'
                'eval:Evaluate a flake path with config override'
                'package:Get store path for package(s)'
            )
            _describe 'commands' commands
            ;;
        args)
            case $line[1] in
                profile)
                    case $CURRENT in
                        2)
                            local subcommands=(
                                'user:Navigate to user directory or edit user config'
                                'edit:Edit active profile configuration file'
                                'select:Set active profile name'
                                'reset:Reset to default profile'
                                'help:Show help message'
                            )
                            _describe 'profile subcommands' subcommands
                            ;;
                        3)
                            case "$line[2]" in
                                user)
                                    _arguments \
                                        '1: :(edit)'
                                    ;;
                                select)
                                    _message "profile name"
                                    ;;
                            esac
                            ;;
                    esac
                    ;;
                build)
                    case $CURRENT in
                        2)
                            _arguments \
                                '--timeout[Set timeout in seconds]:timeout:' \
                                '--dry-run[Test build without actual building]' \
                                '--offline[Build without network access]' \
                                '--diff[Compare built config with current active system]' \
                                '--skip-verification[Skip commit signature verification]'
                            ;;
                    esac
                    ;;
                sync|dry|test|boot)
                    case $CURRENT in
                        2)
                            _arguments \
                                '--offline[Run without network access]' \
                                '--show-trace[Show detailed trace output]' \
                                '--allow-dirty-git[Allow proceeding with uncommitted changes]'
                            ;;
                    esac
                    ;;
                sync|boot)
                    case $CURRENT in
                        2)
                            _arguments \
                                '--skip-verification[Skip commit signature verification]'
                            ;;
                    esac
                    ;;
                rollback)
                    case $CURRENT in
                        2)
                            _arguments \
                                '--allow-dirty-git[Allow proceeding with uncommitted changes]'
                            ;;
                    esac
                    ;;
                log|head|diff|diffc|status|commit|pull|push|add|addp|stash)
                    case $CURRENT in
                        2)
                            _arguments \
                                '--only-core[Run only on core repository]' \
                                '--only-config[Run only on config repository]'
                            ;;
                    esac
                    ;;
                impermanence)
                    case $CURRENT in
                        2)
                            local subcommands=(
                                'check:List files/directories in ephemeral root'
                                'diff:Compare historical impermanence check logs'
                                'logs:Show impermanence rollback logs'
                                'help:Show help message'
                            )
                            _describe 'impermanence subcommands' subcommands
                            ;;
                        3)
                            case "$line[2]" in
                                check)
                                    _arguments \
                                        '--home[Show only paths under /home]' \
                                        '--system[Show only system paths]' \
                                        '*--filter[Filter results by keyword]:keyword:'
                                    ;;
                                diff)
                                    _arguments \
                                        '--range[Compare with Nth previous log]:range:' \
                                        '--home[Compare only home check logs]' \
                                        '--system[Compare only system check logs]'
                                    ;;
                            esac
                            ;;
                    esac
                    ;;
                spec)
                    case $CURRENT in
                        2)
                            _arguments \
                                '--home[Operate on home-manager specializations]' \
                                '1: :(list switch reset)'
                            ;;
                        3)
                            if [[ "$line[2]" == "switch" ]]; then
                                _message "specialization name"
                            fi
                            ;;
                    esac
                    ;;
                modules)
                    case $CURRENT in
                        2)
                            local subcommands=(
                                'list:List available modules'
                                'config:Show complete active configuration'
                                'info:Show detailed module information'
                                'edit:Open module file in editor (creates if doesn'\''t exist)'
                                'help:Show help message'
                            )
                            _describe 'modules subcommands' subcommands
                            ;;
                        3)
                            case "$line[2]" in
                                list)
                                    _arguments \
                                        '--active[Show only active modules]' \
                                        '--inactive[Show only inactive modules]' \
                                        '--profile[Use specific profile]:profile:' \
                                        '--nixos[Force NixOS mode]' \
                                        '--standalone[Force standalone mode]'
                                    ;;
                                config)
                                    _arguments \
                                        '--profile[Use specific profile]:profile:' \
                                        '--arch[Use specific architecture]:architecture:(x86_64-linux aarch64-linux x86_64-darwin aarch64-darwin)' \
                                        '--nixos[Force NixOS mode]' \
                                        '--standalone[Force standalone mode]'
                                    ;;
                                info|edit)
                                    _message "module name (INPUT.GROUP.MODULENAME)"
                                    ;;
                            esac
                            ;;
                    esac
                    ;;
                package)
                    _arguments \
                        '--unstable[Use nixpkgs-unstable instead of nixpkgs]' \
                        '*:package name:_message "package name"'
                    ;;
            esac
            ;;
    esac
}

compdef _nx nx
