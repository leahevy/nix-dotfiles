args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "agents";

  group = "dev";
  input = "common";

  options = {
    disableTestData = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable built-in test skills and agents.";
    };

    instructions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf helpers.optionsHelpers.recursiveStringListType);
      default = { };
      description = "Shared instructions used by agent tools.";
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.either lib.types.str (
          lib.types.submodule {
            options = {
              description = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Skill description.";
              };
              text = lib.mkOption {
                type = lib.types.str;
                description = "Skill instructions.";
              };
            };
          }
        )
      );
      default = { };
      description = "Shared skills used by agent tools.";
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Shared MCP server configurations for agent tools.";
    };

    enabledAgents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Agent CLI names contributed by enabled agent modules.";
    };

    agents = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            description = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Agent description.";
            };
            text = lib.mkOption {
              type = lib.types.str;
              description = "Agent instructions.";
            };
            tools = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "Read"
                "Edit"
                "Write"
              ];
              description = "Allowed tools.";
            };
          };
        }
      );
      default = { };
      description = "Shared custom agents for Claude and OpenCode.";
    };
  };

  exports =
    { lib, ... }:
    let
      renderBulletItem =
        depth: item:
        let
          indent = lib.concatStringsSep "" (lib.genList (_: "    ") depth);
        in
        if lib.isString item then
          "${indent}- ${item}"
        else
          lib.concatStringsSep "\n" (
            [ (renderBulletItem depth (builtins.head item)) ]
            ++ map (renderBulletItem (depth + 1)) (builtins.tail item)
          );
    in
    {
      inherit renderBulletItem;
      renderInstructions =
        instructionsSet:
        let
          headers = lib.sort (a: b: a < b) (builtins.attrNames instructionsSet);
          renderSection =
            header:
            let
              bullets = instructionsSet.${header} or [ ];
              body = lib.concatStringsSep "\n" (map (renderBulletItem 0) bullets);
              displayHeader =
                let
                  m = builtins.match "^[0-9]+[ ]*-[ ]*(.*)$" header;
                in
                if m != null && m != [ ] && (builtins.elemAt m 0) != "" then builtins.elemAt m 0 else header;
            in
            if bullets == [ ] then "" else "## ${displayHeader}\n\n${body}";
          sections = builtins.filter (s: s != "") (map renderSection headers);
        in
        lib.concatStringsSep "\n\n" sections;
    };

  module = {
    enabled =
      config:
      let
        disableTestData = config.nx.common.dev.agents.disableTestData;
        difftasticEnabled =
          (config.programs.difftastic.enable or false) && (config.programs.difftastic.git.enable or false);
        diffAliasedToColordiff = (config.home.shellAliases.diff or null) == "colordiff";
        agentShell =
          if self.isDarwin then
            "zsh"
          else if (config.nx.common.shell.zsh.enable or false) then
            "zsh"
          else
            "bash";
        fishEnabled = config.nx.common.shell.fish.enable or false;

        installedPackages = (config.home.packages or [ ]) ++ (config.environment.systemPackages or [ ]);
        isProgramInstalled = pname: lib.any (p: (p.pname or p.name or "") == pname) installedPackages;
        programInstalledLine = command: purpose: "For ${purpose}, use the installed `${command}`.";
        runtimeFileGuardLine =
          command: purpose: files:
          let
            joined = lib.concatStringsSep " or " (map (f: "`${f}`") files);
          in
          "For ${purpose}, use the installed `${command}`, but only in a project that has ${joined}. Do not use `${command}` in a project without ${joined}.";
        mkSkipLine =
          {
            command,
            label ? null,
            activity ? null,
            alsoAvoid ? [ ],
          }:
          let
            subject = if label != null then "${label} (`${command}`)" else "`${command}`";
            object = if activity != null then activity else "`${command}`";
            avoidList =
              if activity != null then
                lib.concatStringsSep ", " (map (c: "`${c}`") ([ command ] ++ alsoAvoid)) + ", or via `nix shell`"
              else
                "or fetch it via `nix shell`";
          in
          "${subject} is not installed. Do not run ${object} (${avoidList}); skip it instead.";
        skipLineFor =
          command: skip: mkSkipLine ({ inherit command; } // (if lib.isAttrs skip then skip else { }));
        mkProgram =
          {
            command,
            purpose,
            pname ? command,
            attr ? null,
            check ? null,
            skipIfMissing ? false,
          }:
          let
            pnames = if lib.isList pname then pname else [ pname ];
            attrName = if attr != null then attr else builtins.head pnames;
            present = if check != null then check else lib.any isProgramInstalled pnames;
          in
          if present then
            programInstalledLine command purpose
          else if skipIfMissing != false then
            skipLineFor command skipIfMissing
          else
            "`${command}` is not installed. For ${purpose}, run it on demand via `nix shell nixpkgs#${attrName} -c ${command} ...`.";
        mkProgramCustom =
          {
            command,
            purpose,
            whenMissing ? null,
            pname ? command,
            check ? null,
            runtimeFileCheck ? [ ],
            skipIfMissing ? false,
          }:
          let
            present = if check != null then check else isProgramInstalled pname;
            presentLine =
              if runtimeFileCheck != [ ] then
                runtimeFileGuardLine command purpose runtimeFileCheck
              else
                programInstalledLine command purpose;
            missingLine = if skipIfMissing != false then skipLineFor command skipIfMissing else whenMissing;
          in
          if present then presentLine else missingLine;

        baseInstructions = {
          "10 - Work Style" = [
            "Always follow the user's explicit instructions exactly; don't add extra work, refactors, formatting, or \"helpful checks\" unless asked."
            "Before making any code/content changes, state: (a) the symptom/goal, (b) suspected root cause, (c) exact files to change, (d) expected behaviour change."
            "Keep diffs minimal and localised; prefer the smallest change that achieves the goal."
            "If something is ambiguous or high-risk, stop and ask a concrete question rather than guessing."
            "Don't run long-running, expensive, or side-effectful commands without saying exactly what you'll run and why; default to not running them unless requested."
            "Prefer targeted verification over broad verification; propose the smallest check that proves the change works."
            "Treat secrets and sensitive data as off-limits by default: don't print, exfiltrate, or persist tokens/keys/credentials; redact if encountered."
            "Don't change unrelated files; avoid drive-by cleanups (naming, structure, style) unless required for the task."
            "When writing new user-facing text (docs, messages, prompts), keep it concise, direct, and actionable."
            "Do not use Unicode punctuation or symbol variants in comments, prompts, or user-facing text when a plain ASCII form works. Use ASCII equivalents such as -> instead of Unicode arrows."
            "Do not use em dashes or en dashes in comments, prompts, or user-facing text."
            "In code comments, do not use dash punctuation for prose at all. Rewrite the sentence or use commas, parentheses, or separate sentences instead."
            "Keep comments focused and minimal. Do not add verbose, obvious, or repetitive comments."
            "If you introduce new configuration or interfaces, make defaults safe and backward-compatible; fail early with clear errors for invalid inputs."
            "When generating files from configuration, avoid duplicating sources of truth; define clear precedence/merge order and document it briefly."
            "If you need to revert/undo a previous approach, do it explicitly and explain what was wrong and what will change."
            "Do not read or search additional files beyond what is required to complete the user's request."
            "If the user explicitly says \"only change X\" or \"stop reading Y\", treat it as a hard constraint."
            "Minimise tool calls; don't re-read files you already read this session unless there's a concrete reason they could have changed."
            "Do not do a broad repository sweep unless it's required; ask first if it will be large or token-heavy."
          ];
          "70 - Git" =
            lib.optionals difftasticEnabled [
              "Never run `git diff` without `--no-ext-diff`."
            ]
            ++ [
              "Prefer `git --no-pager diff${lib.optionalString difftasticEnabled " --no-ext-diff"}` for consistent output."
              "Never stage, commit, push, pull, or rebase unless the user explicitly asks."
              [
                "For navigating a Git repo to locate files, prefer: `(cd {{REPO_ROOT}} && git ls-files | grep \"{{SEARCH-TERM}}\" | tree --fromfile)`."
                "If the repo is the current one, replace `{{REPO_ROOT}}` with `\"$(git rev-parse --show-toplevel)\"`. If you need a different repo, use its root path explicitly."
              ]
            ];
          "71 - Shell" = [
            "Your shell is `${agentShell}`; run shell tool calls in `${agentShell}` syntax."
            "When writing scripts on disk always unconditionally use `bash` syntax."
          ]
          ++ lib.optionals fishEnabled [
            "The user's own interactive shell is `fish`. Therefore, scripts the user should execute manually should use `fish` syntax."
          ]
          ++ lib.optionals (!fishEnabled) [
            "The user's own interactive shell is `${agentShell}`. Therefore, scripts the user should execute manually should use `${agentShell}` syntax."
          ]
          ++ [
            "`cp`, `mv`, `ln`, and `rm` carry interactive `-i`/`-I` alias guards that hang when run directly; bypass with `command` (e.g. `command cp`). Shebang scripts are unaffected."
          ]
          ++ lib.optionals diffAliasedToColordiff [
            "`diff` is aliased to `colordiff`, which colorizes output and prints a startup banner that corrupts machine-readable output; call the real diff program with `command diff` (e.g. `command diff a b`)."
          ];
          "72 - Available Programs" = [
            (mkProgram {
              command = "jq";
              purpose = "JSON validation and manipulation";
            })
            (mkProgram {
              command = "yq";
              purpose = "YAML, XML, and TOML processing";
            })
            (mkProgram {
              command = "rg";
              pname = "ripgrep";
              attr = "ripgrep";
              purpose = "fast recursive text search";
            })
            (mkProgram {
              command = "fd";
              purpose = "fast file finding";
            })
            (mkProgram {
              command = "curl";
              purpose = "making HTTP requests";
            })
            (mkProgram {
              command = "sqlite3";
              pname = "sqlite";
              attr = "sqlite";
              purpose = "querying SQLite database files";
            })
            (mkProgram {
              command = "wget";
              purpose = "recursive or mirrored downloads";
            })
            (mkProgram {
              command = "pandoc";
              pname = "pandoc-cli";
              attr = "pandoc";
              purpose = "converting between document formats";
            })
            (mkProgram {
              command = "treefmt";
              pname = [
                "nixfmt-tree"
                "treefmt"
              ];
              purpose = "formatting code in a repository that has a treefmt config (e.g. `.treefmt.toml`)";
            })
            (mkProgram {
              command = "shellcheck";
              pname = "ShellCheck";
              attr = "shellcheck";
              purpose = "linting shell scripts";
            })
            (mkProgram {
              command = "shfmt";
              purpose = "formatting and parsing shell scripts";
            })
            (mkProgram {
              command = "jd";
              pname = "jd-diff-patch";
              attr = "jd-diff-patch";
              purpose = "structured JSON diff and patch";
            })
            (mkProgram {
              command = "tree";
              purpose = "viewing directory structure";
            })
            (mkProgram {
              command = "just";
              purpose = "running project tasks in a repository that has a justfile";
            })
            (mkProgram {
              command = "pre-commit";
              purpose = "running hooks in a repository that has a .pre-commit-config.yaml";
            })
            (mkProgramCustom {
              command = "gh";
              purpose = "GitHub operations (PRs, issues, releases)";
              whenMissing = "The GitHub CLI (`gh`) is not installed. To query GitHub, use the REST API directly via `curl` (e.g. `curl https://api.github.com/repos/OWNER/REPO/...`).";
            })
          ];
          "73 - Programming Languages" = [
            (mkProgramCustom {
              command = "tsc";
              pname = "typescript";
              purpose = "TypeScript type-checking";
              skipIfMissing = {
                label = "The TypeScript compiler";
                activity = "TypeScript type-checking";
                alsoAvoid = [ "npx tsc" ];
              };
            })
            (mkProgramCustom {
              command = "go";
              purpose = "building and checking Go code";
              skipIfMissing = {
                label = "The Go toolchain";
                activity = "Go build or checks";
              };
            })
            (mkProgramCustom {
              command = "cargo";
              purpose = "building and checking Rust code";
              skipIfMissing = {
                label = "The Rust toolchain";
                activity = "Rust build or checks";
              };
            })
            (mkProgramCustom {
              command = "python3";
              purpose = "running Python";
              check = config.nx.common.python.python.enable or false;
              skipIfMissing = true;
            })
            (mkProgramCustom {
              command = "uv";
              purpose = "Python dependency and environment management";
              runtimeFileCheck = [ "uv.lock" ];
              skipIfMissing = true;
            })
            (mkProgramCustom {
              command = "poetry";
              purpose = "Python dependency and environment management";
              check = config.nx.common.dev.poetry.enable or false;
              runtimeFileCheck = [ "poetry.lock" ];
              skipIfMissing = true;
            })
          ];
        };

        prePushReviewSkill =
          {
            description ? "Review the outgoing diff for secrets and privacy leaks before pushing.",
            diffCommand,
            branchless ? false,
          }:
          {
            description = "${description} (${diffCommand})";
            text = ''
              - Follow any additional instructions the user provides (e.g. a specific repository path or directory).
              - These take precedence over the steps below.

              ${
                if branchless then
                  ''
                    1) This is a staged-only review.
                       Do not ask for an upstream branch or compare against a target branch.
                  ''
                else
                  ''
                    1) Confirm the branch has an upstream tracking branch:
                       `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
                  ''
              }

              2) Review the diff:
                 `${diffCommand}`

              3) Search the diff for accidental disclosures:
                 - secrets (API keys, tokens, passwords, private keys)
                 - emails / phone numbers / addresses (e.g. "${self.user.email}")
                 - author names and personal identifiers (e.g. "${self.user.fullname}", "${self.user.username}")
                 - hostnames / internal URLs / IPs ${
                   lib.optionalString (!self.user.isStandalone) "(e.g. \"${self.host.hostname}\")"
                 }
                 - credentials in configs, logs, debug output
            '';
          };

        mergeRequestReviewSkill =
          {
            description ? "Review a merge request diff for bugs, style, and safety before merging.",
            diffCommand,
            branchless ? false,
          }:
          {
            description = "${description} (${diffCommand})";
            text = ''
              - Follow any additional instructions the user provides (e.g. a specific repository path or directory)
              - These take precedence over the steps below.

              ${
                if branchless then
                  ''
                    1) This is a staged-only review.
                       Do not ask for a target branch or remote. Review only the cached diff as-is.
                  ''
                else
                  ''
                    1) Determine the merge target:
                       - Identify the target branch (e.g. `main`, `master`, `develop`).
                         If it's unclear, ask the user which target branch to review against.
                       - Choose the remote for the target branch.
                         Default to `origin` unless the user says otherwise.
                  ''
              }

              2) Review the diff:
                 `${diffCommand}`

              3) Review focus:
                 - introduced bugs / broken logic / missing error handling
                 - code style and consistency with repo patterns
                 - safety: accidental sensitive data or risky changes
            '';
          };
        baseSkills = {
          hello-world = {
            description = "A test skill that prints 'Hello World' to the user.";
            text = ''
              Run the 'hostname' command to get the current hostname.

              Then output the following message to the user: "Hello World from ''${hostname}!"
            '';
          };

          review-pre-push-head = prePushReviewSkill {
            diffCommand = "git diff${lib.optionalString difftasticEnabled " --no-ext-diff"} @{u}...HEAD";
          };

          review-pre-push-cached = prePushReviewSkill {
            diffCommand = "git diff${lib.optionalString difftasticEnabled " --no-ext-diff"} --cached";
            branchless = true;
          };

          review-pre-push-workdir = prePushReviewSkill {
            diffCommand = "git diff${lib.optionalString difftasticEnabled " --no-ext-diff"}";
          };

          review-merge-request-head = mergeRequestReviewSkill {
            diffCommand = "git diff${lib.optionalString difftasticEnabled " --no-ext-diff"} TARGET_REMOTE/TARGET_BRANCH...HEAD";
          };

          review-merge-request-cached = mergeRequestReviewSkill {
            diffCommand = "git diff${lib.optionalString difftasticEnabled " --no-ext-diff"} --cached";
            branchless = true;
          };

          review-merge-request-workdir = mergeRequestReviewSkill {
            diffCommand = "git diff${lib.optionalString difftasticEnabled " --no-ext-diff"}";
          };
        };
        baseAgents = {
          hello-world = {
            description = "A test agent that prints 'Hello World' to the user.";
            text = ''
              You are a test agent that prints 'Hello World' to the user.
            '';
          };
        };

        filteredBaseSkills =
          if disableTestData then lib.removeAttrs baseSkills [ "hello-world" ] else baseSkills;
        filteredBaseAgents =
          if disableTestData then lib.removeAttrs baseAgents [ "hello-world" ] else baseAgents;
      in
      {
        nx.common.dev.agents.instructions = lib.mkOrder 100 baseInstructions;

        nx.common.dev.agents.skills = lib.mkOrder 100 filteredBaseSkills;
        nx.common.dev.agents.agents = lib.mkOrder 100 filteredBaseAgents;
      };

    home =
      {
        config,
        mcpServers,
        enabledAgents,
        ...
      }:
      let
        headerTitle = "Agent Hub";
        titleLen = builtins.stringLength headerTitle;
        styleWidth = titleLen + 4;
        headerWidth = styleWidth + 2;
        maxItemLen = lib.foldl' (acc: n: lib.max acc (builtins.stringLength n)) 0 enabledAgents;
        menuWidth = lib.max (builtins.stringLength "Select agent:") (3 + maxItemLen);
        menuOffset = (headerWidth - menuWidth) / 2;
        agentScript =
          if builtins.length enabledAgents == 1 then
            pkgs.writeShellScriptBin "agent" ''
              exec "${builtins.head enabledAgents}"
            ''
          else
            pkgs.writeShellScriptBin "agent" ''
              _tmpfile=$(mktemp)
              trap "rm -f '$_tmpfile'" EXIT

              while true; do
                clear
                COLS=$(${pkgs.ncurses}/bin/tput cols 2>/dev/null || echo 80)
                ROWS=$(${pkgs.ncurses}/bin/tput lines 2>/dev/null || echo 24)
                LEFT=$(( (COLS - ${toString headerWidth}) / 2 ))
                TOP=$(( (ROWS - 10) / 2 ))
                [ "$LEFT" -lt 0 ] && LEFT=0
                [ "$TOP" -lt 0 ] && TOP=0
                printf '%*s' "$TOP" "" | tr ' ' '\n'
                ${pkgs.gum}/bin/gum style \
                  --foreground="212" \
                  --border="rounded" \
                  --border-foreground="99" \
                  --align="center" \
                  --width=${toString styleWidth} \
                  --padding="0 2" \
                  --margin="0 0 0 $LEFT" \
                  "${headerTitle}"
                printf '\n'
                _resized=0
                ${pkgs.gum}/bin/gum choose \
                  --header="Select agent:" \
                  --cursor="-> " \
                  --height=6 \
                  --padding="0 0 0 $(( LEFT + ${toString menuOffset} ))" \
                  --select-if-one \
                  ${lib.concatStringsSep " " (map (n: "\"${n}\"") enabledAgents)} > "$_tmpfile" &
                _gum_pid=$!
                trap "_resized=1; kill $_gum_pid 2>/dev/null" SIGWINCH
                wait $_gum_pid
                trap - SIGWINCH
                ${pkgs.ncurses}/bin/tput cnorm 2>/dev/null
                choice=$(cat "$_tmpfile" 2>/dev/null)
                [ $_resized -eq 1 ] && continue
                [ -z "$choice" ] && exit 0
                "$choice"
              done
            '';
      in
      {
        programs.mcp = {
          enable = true;
          servers = mcpServers;
        };
        home.packages = lib.optional (enabledAgents != [ ]) agentScript;
      };
  };
}
