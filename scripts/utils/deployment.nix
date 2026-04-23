{
  architectures,
  option,
  optionWith,
  optionWithDefault,
  optionWithEnum,
  optionRepeatable,
  arg,
  argVariadic,
  commonDeploymentOptions,
  gitOptions,
}:
{
  name = "nx";
  version = "0.0.1";

  groups = [
    {
      id = "configuration";
      label = "Configuration";
    }
    {
      id = "switch";
      label = "Switch Commands";
    }
    {
      id = "evaluation";
      label = "Evaluation";
    }
    {
      id = "modules";
      label = "Specializations & Modules";
    }
    {
      id = "folder";
      label = "Folder Commands";
    }
    {
      id = "git";
      label = "Git Commands";
    }
  ];

  nx = {
    description = "Manage home-manager or NixOS system";
    options = {
      version = {
        description = "Show version information";
      };
    };
    subcommands = {
      profile = {
        description = "Configure to use profile";
        group = "configuration";
        subcommands = {
          user = {
            description = "Navigate to user directory or edit user config";
            scope = "integrated";
            subcommands = {
              edit = {
                description = "Edit integrated user configuration file";
              };
            };
          };
          edit = {
            description = "Edit active profile configuration file";
          };
          select = {
            description = "Set active profile name";
            arguments = [ (arg "profile" "Profile name" "string") ];
          };
          reset = {
            description = "Reset to default profile";
          };
        };
      };

      build = {
        description = "Test build configuration without deploying";
        group = "switch";
        options = {
          timeout = optionWithDefault "Set timeout in seconds" "seconds" "int" "7200";
          dry-run = option "Test build without actual building";
          offline = option "Build without network access";
          diff = option "Compare built config with current active system";
          show-trace = option "Show detailed Nix error traces";
          show-derivation = option "Show the output derivation in JSON format";
          skip-verification = option "Skip commit signature verification";
          raw = option "Use raw log format";
          allow-ifd = option "Allow import-from-derivation";
          profile = optionWith "Use specific profile" "profile" "string";
          nixos = option "Force NixOS mode";
          standalone = option "Force standalone mode";
          arch = optionWithEnum "Use specific architecture" "architecture" architectures;
        };
      };

      sync = {
        description = "Sync/deploy the system state";
        group = "switch";
        options = commonDeploymentOptions;
      };

      gc = {
        description = "Run the garbage collection";
        group = "switch";
      };

      update = {
        description = "Update the flake in git (without switching)";
        group = "switch";
        modes = [
          "local"
          "develop"
        ];
        arguments = [ (argVariadic "inputs" "Flake input name(s) to update" "string") ];
      };

      bump = {
        description = "Bump the core input to the latest remote commit";
        group = "switch";
        modes = [
          "local"
          "develop"
        ];
        options = {
          commit = option "Commit flake.lock and .label after bumping";
          push = option "Push config after committing (implies --commit)";
        };
      };

      dist-upgrade = {
        description = "Bump NixOS version and migrate packages";
        group = "switch";
        scope = "integrated";
        modes = [ "develop" ];
        arguments = [ (arg "version" "Target NixOS version (XX.XX)" "nixVersion") ];
      };

      brew = {
        description = "Sync Homebrew packages";
        group = "switch";
        modes = [
          "local"
          "develop"
        ];
        system = "darwin";
      };

      configure-nix = {
        description = "Configure system for Nix";
        group = "switch";
        options = {
          check-only = option "Run checks only without making changes";
        };
      };

      dry = {
        description = "Test configuration without deploying";
        group = "switch";
        scope = "integrated";
        options = commonDeploymentOptions;
      };

      test = {
        description = "Activate without adding to bootloader";
        group = "switch";
        scope = "integrated";
        options = commonDeploymentOptions;
      };

      boot = {
        description = "Add to bootloader without switching";
        group = "switch";
        scope = "integrated";
        options = commonDeploymentOptions;
      };

      vm = {
        description = "Build and run a NixOS VM";
        group = "switch";
        scope = "integrated";
        system = "linux";
        modes = [
          "develop"
          "local"
        ];
        options = {
          timeout = optionWithDefault "Set timeout in seconds" "seconds" "int" "7200";
          profile = optionWith "Use specific profile" "profile" "string";
          arch = optionWithEnum "Target architecture for cross-arch builds" "architecture" architectures;
          show-trace = option "Show detailed Nix error traces";
          allow-ifd = option "Allow import-from-derivation";
          skip-verification = option "Skip commit signature verification";
          keep = option "Save VM image with timestamp instead of using ephemeral storage";
          no-run = option "Build VM image without starting it";
          reuse-latest = option "Run the most recently saved image without rebuilding";
          select = optionWith "Run a specific saved image by version name" "version" "string";
          list = option "List all saved VM images for the current profile";
          cleanup = option "Remove all cached VM images for the current profile";
          cleanup-all = option "Remove all cached VM images for all profiles";
          age-system-file = optionWith "Use system age key from file path (no sudo)" "system_path" "filepath";
          age-user-file = optionWith "Use user age key from file path (no sudo)" "user_path" "filepath";
          age-file = optionWith "Use same age key file for both system+user (no sudo)" "path" "filepath";
          no-user-age = option "Skip passing a user age key to the VM";
          dangerously-use-host-sops = option "Allow copying host SOPS age key into VM share via sudo";
        };
      };

      rollback = {
        description = "Rollback to previous configuration";
        group = "switch";
        scope = "integrated";
        options = {
          allow-dirty-git = option "Allow proceeding with uncommitted changes";
        };
      };

      impermanence = {
        description = "Manage ephemeral root filesystems";
        group = "switch";
        scope = "integrated";
        impermanence = "enabled";
        subcommands = {
          check = {
            description = "List files/directories in ephemeral root";
            options = {
              home = option "Show only paths under /home";
              system = option "Show only system paths";
              filter = optionRepeatable "Filter results by keyword" "keyword" "string";
            };
          };
          diff = {
            description = "Compare historical impermanence check logs";
            options = {
              range = optionWith "Compare with Nth previous log" "range" "int";
              home = option "Compare only home check logs";
              system = option "Compare only system check logs";
            };
          };
          logs = {
            description = "Show impermanence rollback logs";
          };
        };
      };

      eval = {
        description = "Evaluate a flake path with config override";
        group = "evaluation";
        options = {
          home = option "Evaluate in home-manager context";
          profile = optionWith "Use specific profile" "profile" "string";
          nixos = option "Force NixOS mode";
          standalone = option "Force standalone mode";
          arch = optionWithEnum "Use specific architecture" "architecture" architectures;
          vm = option "Use VM variant of the configuration";
        };
        arguments = [ (arg "path" "Nix eval path" "string") ];
      };

      package = {
        description = "Get store path for package(s)";
        group = "evaluation";
        options = {
          unstable = option "Use nixpkgs-unstable instead of nixpkgs";
        };
        arguments = [ (argVariadic "packages" "Package name(s)" "string") ];
      };

      version = {
        description = "Show the current NixOS version";
        group = "evaluation";
      };

      config = {
        description = "Open a shell in the config directory";
        group = "folder";
      };

      core = {
        description = "Open a shell in the core directory";
        group = "folder";
        modes = [ "develop" ];
      };

      format = {
        description = "Format directories with treefmt";
        group = "folder";
        modes = [
          "local"
          "develop"
        ];
      };

      exec = {
        description = "Run any command in the directory";
        group = "folder";
        completeFiles = true;
      };

      spec = {
        description = "Manage specializations";
        group = "modules";
        options = {
          home = option "Operate on home-manager specializations";
        };
        subcommands = {
          list = {
            description = "List all available specializations";
          };
          switch = {
            description = "Switch to specified specialization";
            arguments = [ (arg "name" "Specialization name" "string") ];
          };
          reset = {
            description = "Reset to base configuration";
          };
        };
      };

      modules = {
        description = "Manage and inspect NX modules";
        group = "modules";
        subcommands = {
          list = {
            description = "List available modules";
            options = {
              active = option "Show only active modules";
              inactive = option "Show only inactive modules";
              profile = optionWith "Use specific profile" "profile" "string";
              nixos = option "Force NixOS mode";
              standalone = option "Force standalone mode";
              arch = optionWithEnum "Use specific architecture" "architecture" architectures;
              vm = option "Use VM variant of the configuration";
            };
          };
          config = {
            description = "Show complete active configuration";
            options = {
              profile = optionWith "Use specific profile" "profile" "string";
              arch = optionWithEnum "Use specific architecture" "architecture" architectures;
              nixos = option "Force NixOS mode";
              standalone = option "Force standalone mode";
              vm = option "Use VM variant of the configuration";
            };
          };
          info = {
            description = "Show detailed module information";
            arguments = [ (arg "module" "Module name (INPUT.GROUP.MODULE)" "modulePath") ];
            options = {
              profile = optionWith "Use specific profile" "profile" "string";
              arch = optionWithEnum "Use specific architecture" "architecture" architectures;
              nixos = option "Force NixOS mode";
              standalone = option "Force standalone mode";
              vm = option "Use VM variant of the configuration";
            };
          };
          edit = {
            description = "Open module file in editor, creates if needed";
            arguments = [ (arg "module" "Module name (INPUT.GROUP.MODULE)" "modulePath") ];
          };
        };
      };

      log = {
        description = "Run git log command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
      };

      head = {
        description = "Run git show HEAD command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
      };

      diff = {
        description = "Run git diff command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
      };

      diffc = {
        description = "Run git diff --cached command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
      };

      status = {
        description = "Run git status command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
      };

      commit = {
        description = "Run git commit command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
        arguments = [ (arg "message" "Commit message" "string") ];
      };

      pull = {
        description = "Run git pull command";
        group = "git";
        modes = [
          "server"
          "local"
          "develop"
        ];
        options = gitOptions;
      };

      push = {
        description = "Run git push command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions // {
          bump = option "Push nxcore first, then bump and push nxconfig (implies --commit on config)";
        };
      };

      add = {
        description = "Run git add command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
      };

      addp = {
        description = "Run git add --patch command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
      };

      stash = {
        description = "Run git stash command";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
      };

      switch-branch = {
        description = "Switch git branches with safety checks";
        group = "git";
        modes = [
          "local"
          "develop"
        ];
        options = gitOptions;
        arguments = [ (arg "branch" "Branch to switch to" "gitBranch") ];
      };
    };
  };
}
