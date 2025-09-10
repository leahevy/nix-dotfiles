complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "profile" -d "Configure to use profile"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "sync" -d "Sync/deploy the system state"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "build" -d "Test build configuration without deploying"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "gc" -d "Run the garbage collection"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "update" -d "Update the flake in git (without switching)"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "dry" -d "Test configuration without deploying (NixOS only)"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "test" -d "Activate without adding to bootloader (NixOS only)"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "boot" -d "Add to bootloader without switching (NixOS only)"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "rollback" -d "Rollback to previous configuration (NixOS only)"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "news" -d "Show recent news (Home Manager only)"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "config" -d "Open a shell in the config directory"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "core" -d "Open a shell in the core directory"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "format" -d "Format directories with treefmt"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "exec" -d "Run any command in the directory"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log head diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "log" -d "Run git log command"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log head diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "head" -d "Run git show HEAD command"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log head diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "diff" -d "Run git diff command"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "diffc" -d "Run git diff command with --cached"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "status" -d "Run git status command"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "commit" -d "Run git commit command"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "pull" -d "Run git pull command"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "push" -d "Run git push command"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "add" -d "Run git add command"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "addp" -d "Run git add command with --patch"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "stash" -d "Run git stash command"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "impermanence" -d "Manage ephemeral root filesystems"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "spec" -d "Manage specializations"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "modules" -d "Manage and inspect NX modules"
complete -c nx -n "not __fish_seen_subcommand_from profile sync build gc update dry test boot rollback news config core format exec log diff diffc status commit pull push add addp stash impermanence spec modules eval" -a "eval" -d "Evaluate a flake path with config override"

# Command-specific options
complete -c nx -n "__fish_seen_subcommand_from profile" -n "test (count (commandline -opc)) = 2" -f
complete -c nx -n "__fish_seen_subcommand_from profile" -n "test (count (commandline -opc)) = 2" -l reset -d "Reset to default profile"
complete -c nx -n "__fish_seen_subcommand_from build" -n "test (count (commandline -opc)) = 2" -f
complete -c nx -n "__fish_seen_subcommand_from build" -n "test (count (commandline -opc)) = 2" -l timeout -d "Set timeout in seconds" -r
complete -c nx -n "__fish_seen_subcommand_from build" -n "test (count (commandline -opc)) = 2" -l dry-run -d "Test build without actual building"
complete -c nx -n "__fish_seen_subcommand_from build" -n "test (count (commandline -opc)) = 2" -l offline -d "Build without network access"
complete -c nx -n "__fish_seen_subcommand_from sync dry test boot" -n "test (count (commandline -opc)) = 2" -f
complete -c nx -n "__fish_seen_subcommand_from sync dry test boot" -n "test (count (commandline -opc)) = 2" -l offline -d "Run without network access"
complete -c nx -n "__fish_seen_subcommand_from sync dry test boot" -n "test (count (commandline -opc)) = 2" -l show-trace -d "Show detailed trace output"
complete -c nx -n "__fish_seen_subcommand_from log diff diffc status commit pull push add addp stash" -n "test (count (commandline -opc)) = 2" -f
complete -c nx -n "__fish_seen_subcommand_from log head diff diffc status commit pull push add addp stash" -n "test (count (commandline -opc)) = 2" -l only-core -d "Run only on core repository"
complete -c nx -n "__fish_seen_subcommand_from log head diff diffc status commit pull push add addp stash" -n "test (count (commandline -opc)) = 2" -l only-config -d "Run only on config repository"

# 'nx impermanence'
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "not __fish_seen_subcommand_from check logs help" -f
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "not __fish_seen_subcommand_from check logs help" -a "check" -d "List files/directories in ephemeral root"
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "not __fish_seen_subcommand_from check logs help" -a "logs" -d "Show impermanence rollback logs"
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "not __fish_seen_subcommand_from check logs help" -a "help" -d "Show help message"

# 'nx impermanence check'
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "__fish_seen_subcommand_from check" -f
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "__fish_seen_subcommand_from check" -l home -d "Show only paths under /home"
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "__fish_seen_subcommand_from check" -l system -d "Show only system paths"
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "__fish_seen_subcommand_from check" -l filter -d "Filter results by keyword" -r

# 'nx impermanence logs'
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "__fish_seen_subcommand_from logs" -f

# 'nx impermanence help'
complete -c nx -n "__fish_seen_subcommand_from impermanence" -n "__fish_seen_subcommand_from help" -f

# 'nx spec'
complete -c nx -n "__fish_seen_subcommand_from spec" -n "not __fish_seen_subcommand_from list switch reset" -f
complete -c nx -n "__fish_seen_subcommand_from spec" -n "not __fish_seen_subcommand_from list switch reset" -n "test (count (commandline -opc)) = 2" -l home -d "Operate on home-manager specializations"
complete -c nx -n "__fish_seen_subcommand_from spec" -n "not __fish_seen_subcommand_from list switch reset" -a "list" -d "List all available specializations"
complete -c nx -n "__fish_seen_subcommand_from spec" -n "not __fish_seen_subcommand_from list switch reset" -a "switch" -d "Switch to specified specialization"
complete -c nx -n "__fish_seen_subcommand_from spec" -n "not __fish_seen_subcommand_from list switch reset" -a "reset" -d "Reset to base configuration"

# 'nx spec'
complete -c nx -n "__fish_seen_subcommand_from spec" -n "__fish_seen_subcommand_from list" -f
complete -c nx -n "__fish_seen_subcommand_from spec" -n "__fish_seen_subcommand_from reset" -f

# 'nx modules'
complete -c nx -n "__fish_seen_subcommand_from modules" -n "not __fish_seen_subcommand_from list config info edit create help" -f
complete -c nx -n "__fish_seen_subcommand_from modules" -n "not __fish_seen_subcommand_from list config info edit create help" -a "list" -d "List available modules"
complete -c nx -n "__fish_seen_subcommand_from modules" -n "not __fish_seen_subcommand_from list config info edit create help" -a "config" -d "Show complete active configuration"
complete -c nx -n "__fish_seen_subcommand_from modules" -n "not __fish_seen_subcommand_from list config info edit create help" -a "info" -d "Show detailed module information"
complete -c nx -n "__fish_seen_subcommand_from modules" -n "not __fish_seen_subcommand_from list config info edit create help" -a "edit" -d "Open module file in editor"
complete -c nx -n "__fish_seen_subcommand_from modules" -n "not __fish_seen_subcommand_from list config info edit create help" -a "create" -d "Create new module from template"
complete -c nx -n "__fish_seen_subcommand_from modules" -n "not __fish_seen_subcommand_from list config info edit create help" -a "help" -d "Show help message"

# 'nx modules list'
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from list" -f
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from list" -l active -d "Show only active modules"
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from list" -l inactive -d "Show only inactive modules"
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from list" -l profile -d "Use specific profile" -r
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from list" -l nixos -d "Force NixOS mode"
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from list" -l standalone -d "Force standalone mode"

# 'nx modules config'
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from config" -f
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from config" -l profile -d "Use specific profile" -r
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from config" -l arch -d "Use specific architecture" -r
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from config" -l nixos -d "Force NixOS mode"
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from config" -l standalone -d "Force standalone mode"

# 'nx modules info', 'nx modules edit', and 'nx modules create'
complete -c nx -n "__fish_seen_subcommand_from modules" -n "__fish_seen_subcommand_from info edit create" -f

# Other commands
complete -c nx -n "__fish_seen_subcommand_from gc rollback news config core update eval" -f
complete -c nx -n "__fish_seen_subcommand_from commit" -f

# Universal commands
complete -c nx -l help -d "Show help message"
complete -c nx -l version -d "Show version information"
