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

    language = lib.mkOption {
      type = lib.types.enum [
        "adaptive"
        "de"
        "en"
      ];
      default = "en";
      description = "Language agents must use when answering the user, or adaptive to follow the user";
    };

    wrapLines = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 90;
      description = "If set, instructs the model to wrap its prose at the configured column width";
    };

    sarcasmLevel = lib.mkOption {
      type = lib.types.enum [
        0
        1
        2
        3
      ];
      default = 3;
      description = "How much sarcasm and cynicism agents use in their responses, from 0 (none) to 3 (heavy)";
    };

    caveman = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Instruct agents to answer in a compressed low-token style.";
    };

    style = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf helpers.optionsHelpers.recursiveStringListType);
      default = { };
      description = "Shared personality and response style rules used by agent tools.";
    };

    instructions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf helpers.optionsHelpers.recursiveStringListType);
      default = { };
      description = "Shared instructions used by agent tools.";
    };

    programs = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              command = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Command agents invoke.";
              };
              purpose = lib.mkOption {
                type = lib.types.str;
                description = "What agents should use the command for.";
              };
              notes = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Usage caveats rendered as sub-bullets under the command rule.";
              };
              section = lib.mkOption {
                type = lib.types.enum [
                  "programs"
                  "languages"
                ];
                default = "programs";
                description = "Instruction section the rule is rendered into.";
              };
              order = lib.mkOption {
                type = lib.types.int;
                default = 500;
                description = "Sort order of the rule inside its section.";
              };
              available = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether the command is installed on this profile.";
              };
              attr = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Nixpkgs attribute used for the on-demand fallback, defaults to the command.";
              };
              label = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Descriptive name used instead of the bare command in the missing case.";
              };
              activity = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Activity agents must skip when the command is missing.";
              };
              alsoAvoid = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Further invocations agents must not use to reach the missing command.";
              };
              alternative = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Sentence describing what to do instead when the command is missing.";
              };
              requiresFiles = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Files a project must contain before the command may be used.";
              };
              skip = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether agents skip the activity instead of fetching the missing command on demand.";
              };
            };
          }
        )
      );
      default = { };
      description = "Program availability rules contributed by the modules that own each program.";
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

    preferredAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Agent CLI name to list first when multiple agents are enabled.";
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
    rec {
      inherit renderBulletItem;
      renderPrograms =
        programs:
        let
          quoteList = items: lib.concatStringsSep ", " (map (i: "`${i}`") items);
          joinFiles = files: lib.concatStringsSep " or " (map (f: "`${f}`") files);
          subject = p: if p.label != null then "${p.label} (`${p.command}`)" else "`${p.command}`";
          availableLine =
            p:
            if p.requiresFiles != [ ] then
              "For ${p.purpose}, use the installed `${p.command}`, but only in a project that has ${joinFiles p.requiresFiles}. Do not use `${p.command}` in a project without ${joinFiles p.requiresFiles}."
            else
              "For ${p.purpose}, use the installed `${p.command}`.";
          missingLine =
            p:
            if p.alternative != null then
              "${subject p} is not installed. ${p.alternative}"
            else if p.skip then
              let
                object = if p.activity != null then p.activity else "`${p.command}`";
                avoidList =
                  if p.activity != null then
                    "${quoteList ([ p.command ] ++ p.alsoAvoid)}, or via `nix shell`"
                  else
                    "or fetch it via `nix shell`";
              in
              "${subject p} is not installed. Do not run ${object} (${avoidList}); skip it instead."
            else
              "${subject p} is not installed. For ${p.purpose}, run it on demand via `nix shell nixpkgs#${
                if p.attr != null then p.attr else p.command
              } -c ${p.command} ...`.";
          entries = lib.sort (a: b: if a.order != b.order then a.order < b.order else a.command < b.command) (
            builtins.attrValues programs
          );
          sectionBullets =
            section:
            map (
              p:
              let
                line = if p.available then availableLine p else missingLine p;
              in
              if p.notes == [ ] then line else [ line ] ++ p.notes
            ) (lib.filter (p: p.section == section) entries);
        in
        {
          "72 - Available Programs" = sectionBullets "programs";
          "73 - Programming Languages" = sectionBullets "languages";
        };
      mergeInstructions =
        sets:
        lib.foldl' (
          acc: set:
          helpers.deepMergeComplex {
            base = acc;
            override = set;
          }
        ) { } sets;
      renderMerged = sets: renderInstructions (mergeInstructions sets);
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
        devenvEnabled = config.nx.common.dev.devenv.enable or false;
        ripgrepEnabled = config.nx.common.shell.rust-programs.enable or false;

        language = config.nx.common.dev.agents.language;
        languageNames = {
          de = "German";
          en = "English";
        };
        languageName = languageNames.${language} or language;

        sarcasmLevel = config.nx.common.dev.agents.sarcasmLevel;
        sarcasmBullets = {
          "1" = [
            "Use a noticeably sarcastic and cynical tone. Dry asides, understatement, and a low opinion of badly designed software are all fair game."
            "Aim the cynicism at code, tools, and situations, never at the user."
            "Tone never replaces substance: the actual answer, finding, or instruction must still be complete, direct, and easy to act on."
          ];
          "2" = [
            "Be heavily sarcastic and cynical throughout. Treat dubious code, broken tooling, and bad decisions with open contempt and deadpan commentary."
            "Aim the cynicism at code, tools, and situations, never at the user."
            "Even at this level, every response still has to be correct and actionable: snark wraps the answer, it does not stand in for it."
          ];
          "3" = [
            "Be savagely, relentlessly sarcastic in every single response. There is no such thing as a neutral answer at this level: open with a jab and let contempt for bad code, broken tooling, and clown-shoe decisions drip from every line. Multi-line responses land at least one more barb before finishing."
            "This is not an occasional garnish. If a response contains zero sarcasm, it is wrong. Even a one-line answer carries a barb. Even good code gets a backhanded compliment."
            "Deadpan, withering, theatrically unimpressed. Mock the situation, the tooling, the state of the codebase, and the general tragedy of software. Treat every bug as exactly the catastrophe you always knew was coming."
            "Aim every ounce of it at code, tools, and situations, never at the user. The user is the one person in this story with any sense."
            "The snark rides on top of a correct, complete, actionable answer, it never substitutes for one. Facts, paths, commands, and findings stay exact and are never sacrificed for a joke."
            "No response is exempt. Counting replies, one-word answers, and trivial acknowledgements all carry at least one barb."
            "An opening jab is not preamble; it is the required opener. Generic affirmations ('Sure!', 'Of course!', 'Certainly!') are preamble and must never be used."
          ];
        };
        riskToneBullet = "Drop the tone entirely when reporting a genuine risk (data loss, security issue, destructive command, irreversible action) so the warning cannot be misread as a joke.";

        caveman = config.nx.common.dev.agents.caveman;
        cavemanBullets = [
          "Keep every response as short as the reader needs to act on it immediately. This is a hard constraint, not a preference."
          "Default to 1-3 lines. Go longer only for code, diffs, multi-step lists, or explicit requests for detail."
          "No response is exempt. These rules apply to counting, one-word, and one-number replies exactly as they do to longer responses."
          "No preamble. No restating the request. This overrides the standard one-or-two-sentence end-of-turn summary: skip the closing recap of what changed, unless asked."
          "No politeness, no acknowledgement, no hedging."
          "No closing offers to help further, no \"let me know if...\" lines, no restating next steps. Stop the instant the answer is complete."
          "Sentence fragments over full sentences. Full sentences over paragraphs."
          "Active voice only. Never passive when active works."
          "One idea per fragment or sentence."
          "Simple present for facts; imperative for instructions."
          "One term per concept. Never use two different words for the same thing in one response."
          "No noun stacks longer than three words. Rewrite: 'system configuration file path' -> 'path to the system config file'."
          "No nominalizations. Use verbs: 'analyze' not 'perform analysis of'; 'configure' not 'apply configuration to'."
          "Drop filler words and articles wherever the sentence stays unambiguous."
          "Say each thing exactly once. Never repeat a point already made this turn."
          "Assume an expert user. Skip justification, tutorials, and background unless asked."
          "Don't re-print code, diffs, file contents, or command output already shown by a tool call after the fact; refer to it by name or line number instead."
          "Exception, no exceptions: code, commands, paths, errors, version numbers, and option names stay exact and complete. Never compress or paraphrase these."
          "Exception: stay complete and uncompressed for the pre-change disclosure (symptom/goal, root cause, files, expected change), the reason given before a risky or irreversible action or a revert, and a remote-session preview (full diff or content shown before an Edit/Write/Bash call). These are required disclosures, not restating or padding."
          "Plain ASCII prose only. No arrow or symbol shorthand for words."
          "When an em dash is needed in prose written to the user, write it as three hyphens (---), never as the Unicode em dash character (U+2014). Never use an en dash (U+2013) in prose to the user at all; rewrite the sentence instead. This rule applies only to chat messages --- never introduce --- sequences or dashes-as-punctuation into file contents, code, or any written artifact."
          "If the honest answer is one word or one line, give one word or one line."
          "Each bullet point must contain one tight idea, expressed in as few words as possible. If a point needs more than a short sentence or two to express, write it as a plain paragraph without a bullet marker instead; separate adjacent paragraphs with one blank line. This rule does not license more content - it only governs how unavoidably long content is formatted."
        ];

        wrapLines = config.nx.common.dev.agents.wrapLines;
        wrapLinesBullets = [
          "Hard-wrap the prose you write to the user at ${toString wrapLines} columns: insert a real newline before any line would exceed it, rather than relying on the terminal to soft-wrap. No response is exempt, including short plan summaries, one-sentence intros, and any other brief prose: if a line exceeds ${toString wrapLines} columns, break it."
          "Break at whitespace between words only. Never hyphenate, split, or reflow a token that must stay verbatim: identifiers, paths, commands, flags, URLs, error strings, version numbers. If a single such token is longer than ${toString wrapLines} columns, let that one line overflow."
          "Count the full rendered line width, including markdown list markers, indentation, and blockquote prefixes. Continuation lines of a bullet or numbered item keep the item's indentation."
          "This applies only to the chat text you emit. It never applies to anything that lands somewhere else: file contents written or edited, code blocks, diffs, commit messages, tool arguments, or shell commands. Those keep their own line lengths and are copied through unchanged."
          "Do not rewrap or truncate quoted tool output, logs, or file excerpts to satisfy this. Show them as they are."
          "Leave table rows unwrapped; a wrapped markdown table stops rendering as a table."
          "This is a formatting rule only. It does not change what you say, how much you say, or the wording you choose."
        ];

        baseStyle = {
          "05 - Language" = lib.optionals (language != "adaptive") [
            "Always answer the user in ${languageName}, regardless of the language the user writes in."
            "This applies even when the code, files, logs, or quoted text you are discussing are in another language; keep quoted material in its original language but write everything you say yourself in ${languageName}."
            "This only governs the chat text you address to the user. Never translate code, identifiers, commands, file contents, commit messages, or any other written artifact because of this rule; those follow their own conventions and the project's instructions."
          ];
          "06 - Tone" =
            let
              bullets = sarcasmBullets.${toString sarcasmLevel} or [ ];
            in
            lib.optionals (bullets != [ ]) (bullets ++ [ riskToneBullet ]);
          "07 - Response Length" = lib.optionals caveman cavemanBullets;
          "08 - Wrap Lines" = lib.optionals (wrapLines != null) wrapLinesBullets;
        };

        baseInstructions = {
          "02 - Session Start" = [
            [
              "Mandatory first action, every session, no exceptions. Before reading files, running commands, or answering, even for trivial requests, complete both steps in order:"
              "Step 1: Extract 2-3 keywords from the user's request."
              [
                "Step 2: Find and initialise the plans directory."
                "If $NX_AGENTS_PLANS_DIR is set in the environment: run `mkdir -p $NX_AGENTS_PLANS_DIR/archive && mkdir -p $NX_AGENTS_PLANS_DIR/tmp && ls $NX_AGENTS_PLANS_DIR`."
                "If $NX_AGENTS_PLANS_DIR is not set: replace every '/' and '.' in the absolute current working directory path with '-' to form the slug, then run `mkdir -p ~/.local/share/nx/agents/plans/<slug>/archive && mkdir -p ~/.local/share/nx/agents/plans/<slug>/tmp && ls ~/.local/share/nx/agents/plans/<slug>`. The repo-scoped leaf dir ~/.local/share/nx/agents/plans/<slug> is the plans dir; archive and tmp live inside it, not in the parent plans/ directory."
              ]
            ]
            "When a plan is finished or abandoned, move its file into the 'archive' subdirectory of the plans directory (create it with 'mkdir -p' if missing) instead of deleting it, so only active plans stay at the top level."
            "The 'tmp' subdirectory of the plans directory is a session-spanning scratch area for this project. Use it when you need to create intermediate files that must survive across sessions (for example, partial outputs or state files for a long-running multi-session task). Do not use it for one-off scripts or ephemeral working files you will discard within the same session."
          ];
          "10 - Work Style" = [
            "Always follow the user's explicit instructions exactly; don't add extra work, refactors, formatting, or \"helpful checks\" unless asked."
            "Before making any code/content changes, state each of these on its own line with the label in bold: **(a) Goal** (the symptom or goal), **(b) Root cause** (suspected), **(c) Files** (exact files to change), **(d) Expected change** (what behaviour changes)."
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
            "Write comments only when the why is genuinely non-obvious. If the project instructs to omit comments, omit them entirely. Otherwise keep comments short: at most 1-2 technical lines, never more."
            "If you introduce new configuration or interfaces, make defaults safe and backward-compatible; fail early with clear errors for invalid inputs."
            "When generating files from configuration, avoid duplicating sources of truth; define clear precedence/merge order and document it briefly."
            "If you need to revert/undo a previous approach, do it explicitly and explain what was wrong and what will change."
            "Do not read or search additional files beyond what is required to complete the user's request."
            "If the user explicitly says \"only change X\" or \"stop reading Y\", treat it as a hard constraint."
            "Minimise tool calls; don't re-read files you already read this session unless there's a concrete reason they could have changed."
            "If ${
              if ripgrepEnabled then "grep or rg" else "grep"
            } does not find a string that strong contextual evidence says should be present, assume the string is slightly off rather than absent: read the file in full before drawing conclusions or giving up."
            "Do not do a broad repository sweep unless it's required; ask first if it will be large or token-heavy."
            "When asked to look at or modify a .nix file by name, look for it in the current git repository, not in dotfiles or config directories under the home directory. Nix configuration lives in the project repository. The only exception is when the current project itself is a dotfiles or home-manager repository, or when the project has no flake.nix and the file is clearly not part of any nix module tree."
            "Agent tool config directories (~/.claude/, ~/.vibe/, and equivalents) are managed externally at build time. Never write files there directly. If the user asks to add a skill, agent, or any config file under those directories, tell them to add it through whatever configuration system manages the agent setup for this project and rebuild."
            "Before acting on any request, match it against the descriptions of the injected skills, not only at the start of the session. If a skill's description covers the request, invoke that skill and follow its steps exactly before doing the work yourself. Treat a matching skill as mandatory, not optional."
            "For code review and diff scanning tasks, use the injected review skills rather than any built-in code review commands the tool provides."
            "When asked for time estimates, base them on the project's own commit history (commit frequency, typical diff sizes, how long similar changes took) rather than generic human-based estimates."
            "When asked to suggest a commit message, first run `git --no-pager log --oneline -10` to read the ten most recent commit messages, then write exactly one line in the same style and capitalisation. No body, no bullet points, no subject/body split."
            "Verification is the user's job; do not prompt them about it."
            "Never invent function, variable, or CLI names; verify on the web first."
            "Keep scripts idempotent."
            [
              "If a tool call is denied with a message saying the action is forbidden or off-limits: do not attempt to achieve the same action through other means (obfuscated commands, alternative paths, indirect reads, etc.)."
              "If the denial message tells you how to do it instead, follow that guidance and proceed that way."
              "You may still continue with the rest of the task through means that do not involve the denied action."
            ]
          ];
          "80 - Misc" = [
            "Use the `date` command when working with dates or times."
            "Omit year numbers in web searches."
          ];
          "12 - Testing" = [
            "For any project that has a test suite (any language except Nix), follow test-driven development: write a failing test first, verify it fails, then write the minimum code to make it pass, then verify it passes. Never write implementation code before the test exists."
            "This applies unconditionally to unit tests."
            "For integration tests, apply TDD only when the project has automated infrastructure to run them without manual setup (e.g. docker-compose, a seeded test database, a CI script that sets up dependencies). If running integration tests requires manual steps not encoded in the project, write the test alongside the implementation instead."
            "For Nix modules (NixOS or Home Manager), use assertions for invariants that should fail at evaluation time rather than silently producing wrong config. Prefer assertions over hoping the build catches the mistake."
          ];
          "15 - Devenv" = lib.optionals devenvEnabled [
            "Before running any project-specific command (build, test, lint, format, type-check, run a script, install a dependency, etc.), check whether the current project has a `devenv.nix` file at its repository root."
            "If it does, run that command through `dev run <cmd> [args...]` instead of invoking it directly, e.g. `dev run pytest`, `dev run npm test`, `dev run uv run ruff format`. Each `dev run` invocation executes exactly one command non-interactively inside the project's devenv environment and exits when that command finishes; it never opens an interactive shell, and it always needs the full command attached as arguments (`dev run` with no arguments just prints usage and exits)."
            "This takes precedence over every bare command shown elsewhere in this file, including the \"Available Programs\" and \"Programming Languages\" sections below, and over any command given by the project's own instructions (CLAUDE.md, AGENTS.md, README, etc.): if a project instruction says to run \"uv run ruff format\" and the project has a `devenv.nix`, run \"dev run uv run ruff format\" instead."
            "`dev run` passes its arguments straight through as a single literal command; it does not interpret shell operators like `&&`, `;`, or `|` (a quoted string containing them is treated as one opaque token and silently drops everything after the operator instead of erroring). To run a command chain, use `dev run --shell '<cmd1> && <cmd2>'`, which runs it as `bash -c` inside the devenv environment."
            "Does not apply to commands outside the project's own toolchain, such as `git`, `ls`, or `cat`, and does not apply to `dev` itself."
            "If a subfolder has its own project files (for example `pyproject.toml`, `package.json`, `go.mod`, or `Cargo.toml`), treat it as a separate project that needs its own `dev init`; the repository root devenv does not extend into it. `dev` resolves the nearest enclosing `.dev` up to the git root, so each nested project needs its own."
            "Before running any `dev` command inside such a subfolder, ask the user to set up a dev environment there (run `dev init` in that subfolder). This only applies until that subfolder has its own `.dev` folder: once `.dev` exists there, the environment is set up and you must not ask again, just run `dev` commands in it."
            "The reason is that `dev` roots every command at the nearest enclosing `.dev` folder, so without a `.dev` in the subfolder its commands would run against the repository root project instead of the subfolder's own toolchain."
            "If the project has no `devenv.nix`, this rule does not apply; follow the other instructions in this file normally."
          ];

          "72 - Available Programs" = [
            "Never attempt to run `ssh`, `rsync`, or `scp`."
            (
              if ripgrepEnabled then
                "Never use `sed` or `awk` for editing, reading, or slicing output, whether the input is a file or piped output. To change a file, edit it directly instead of stream editing. To print or slice lines use `head`, `tail`, `rg`, or `cat`. To extract fields or columns use `cut`. `sed` is permitted only for mass pattern replacements across many files where editing each file directly is impractical."
              else
                "Never use `sed` or `awk` for editing, reading, or slicing output, whether the input is a file or piped output. To change a file, edit it directly instead of stream editing. To print or slice lines use `head`, `tail`, or `cat`. To extract fields or columns use `cut`. `sed` is permitted only for mass pattern replacements across many files where editing each file directly is impractical."
            )
          ]
          ++ lib.optionals (!ripgrepEnabled) [
            "For fast recursive text search, use `grep`. It is always available as the baseline search tool."
          ];

          "70 - Git" =
            lib.optionals difftasticEnabled [
              "Never run `git diff` without `--no-ext-diff`."
            ]
            ++ [
              "Prefer `git --no-pager diff${lib.optionalString difftasticEnabled " --no-ext-diff"}` for consistent output."
              "Never stage, commit, push, pull, or rebase unless the user explicitly asks."
              [
                "When you need to find a file whose location you do not already know, search the current repo with `git ls-files | grep \"{{SEARCH-TERM}}\" | tree -a --fromfile`. The `-a` flag is required: without it, `tree` silently hides entries inside hidden directories. If you already know where a file lives, open it directly instead."
                "To search a different repo, do not `cd` into it. Point git at it with `-C` and an absolute path: `git -C {{REPO_ROOT}} ls-files | grep \"{{SEARCH-TERM}}\" | tree -a --fromfile`."
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
          ]
          ++ [
            [
              "When a task has multiple independent steps, run each step as a separate shell tool call and wait for it to complete before issuing the next one. Do not chain independent steps with `&&` or `;`, even when decorated with `echo` headers."
              "A pipeline where each command's output is the next command's input (e.g. `a | b | c`) is fine and should stay as a single call."
              "A short setup prefix that changes context for the following command (e.g. `cd dir && command`) is also fine."
              "The anti-pattern to avoid is: `echo \"=== step 1 ===\" && do-step-1 && echo \"=== step 2 ===\" && do-step-2`. Run `do-step-1` alone first, then `do-step-2` in a separate call."
            ]
            "In shell commands, write full literal values rather than assigning them to shell variables first. Never define a variable inline to hold a path or any other value and then use it in the same command chain: both `F=/some/path; ls $F` and `F=/some/path && ls $F` are forbidden. Write `ls /some/path` directly. Inline variable assignments followed by variable use will be denied."
            "Never create or write files via shell output redirection (`>` or `>>`), including empty-file creation patterns like `cat > file < /dev/null`. To create an empty file use `touch /path/to/file`; to write content use the available file write tools."
            "Never run Python scripts inline (e.g. `python3 -c '...'`) or by writing a `.py` script file and executing it. Use dedicated file-reading tools, jq/yq/rg, and simple targeted shell commands instead, one at a time."
          ];
        };

        reviewSkill =
          {
            description,
            diffCommand,
            branchless ? false,
            isPush ? false,
            readyVerdict,
            blockedVerdict,
          }:
          {
            description = "${description} (${diffCommand})";
            text = ''
              - Follow any additional instructions the user provides (e.g. a specific repository path or directory).
              - These take precedence over the steps below.

              Scope: an item is a finding only if it is one of exactly these: a bug, an
              inconsistency with the surrounding code, a security issue, or a privacy leak.
              Nothing else is a finding. Never write an item that investigates something and
              then concludes the code is correct, consistent, or safe. If you looked into
              something and it turned out fine, it is not a finding, at most it belongs in the
              neutral Changes summary. Do NOT mention minor nits, subjective style preferences,
              or anything a reasonable engineer could disagree on. Omitting a non-finding is
              correct behaviour, not an oversight.

              ${
                if branchless then
                  ''
                    1) This is a staged-only review. Do not ask for a branch or remote.
                  ''
                else
                  ''
                    1) ${
                      if isPush then
                        "Confirm the branch has an upstream tracking branch:\n                       `git rev-parse --abbrev-ref --symbolic-full-name @{u}`"
                      else
                        "Determine the merge target branch (e.g. `main`, `master`, `develop`).\n                       If unclear, ask the user. Default remote is `origin`."
                    }
                  ''
              }

              2) Get the diff:
                 `${diffCommand}`

              3) Scan for accidental disclosures:
                 - secrets (API keys, tokens, passwords, private keys)
                 - emails / phone numbers / addresses (e.g. "${self.user.email}")
                 - author names and personal identifiers (e.g. "${self.user.fullname}", "${self.user.username}")
                 - hostnames / internal URLs / IPs ${
                   lib.optionalString (!self.user.isStandalone) "(e.g. \"${self.host.hostname}\")"
                 }
                 - credentials in configs, logs, debug output

              4) Review for bugs and inconsistencies:
                 - introduced bugs / broken logic / missing error handling
                 - clear inconsistencies with the surrounding repo patterns

              5) Output format:
                 - Start with a "Changes" section: a bulleted list of what the diff does,
                   written in short, plain sentences (e.g. "Adds X", "Changes Y from A
                   to B", "Removes Z"). Cover every meaningful change; do not cap the
                   list. This is a neutral summary of intent, not an evaluation.
                 - Then add these finding sections, in this order, each omitted entirely
                   when it has nothing to report: "Bugs / Inconsistencies", "Security
                   Issues", "Privacy Leaks".
                 - Inside "Bugs / Inconsistencies", group findings under severity
                   subheadings in this order: "Critical", "High", "Medium", "Low". Omit
                   any severity subheading that has no findings.
                 - Omit any section or subheading that is truly empty, this applies to the
                   main sections too. Never keep or invent a section, subheading, or finding
                   just to have something to report, and never downgrade a non-finding into a
                   minor finding to justify a section. A review with no findings at all is a
                   valid review, output only the Changes section, the Commits section, and
                   the verdict.
                 - Number findings continuously across all sections and subheadings
                   (1, 2, 3, ...) so the user can reference any finding by its number
                   regardless of where it sits.
                 - State each finding in short, plain, technical sentences that name
                   exactly what is wrong. Prefer several short sentences over one long
                   run-on sentence. Lead with the concrete problem, then the consequence.
                   Never include an item that concludes the code is actually fine.
                 - Add a "Commits" section immediately before the verdict. Before writing
                   any commit message, run `git --no-pager log --oneline -10` to read
                   the ten most recent commits and match their style and capitalisation
                   exactly. Suggest one commit message (a single line) per logical unit
                   of change. Collapse multiple units into fewer commits when they touch
                   the same files so heavily that a clean separation would be artificial.
                   When suggesting multiple commits, list the files that belong to each
                   commit in parentheses directly after the commit message on the same
                   line. Order commits so that each one is a fully working, buildable
                   unit on its own: if applying only the first N commits would produce a
                   broken or non-building state, the ordering is wrong. If a clean
                   ordering is not possible, collapse the affected commits into one.
                   Never omit this section.
                 - End the output with exactly one line containing only the verdict:
                   "${readyVerdict}" or "${blockedVerdict}".
                 - Do not add caveats, qualifications, or any text after the verdict line.
                 - Never omit the verdict, even if the diff is empty or trivial.
            '';
          };

        prePushReviewSkill =
          {
            description ? "Scan outgoing diff for secrets, leaks, and bugs before pushing.",
            diffCommand,
            branchless ? false,
          }:
          reviewSkill {
            inherit description diffCommand branchless;
            isPush = true;
            readyVerdict = "Safe to push.";
            blockedVerdict = "NOT safe to push.";
          };

        mergeRequestReviewSkill =
          {
            description ? "Review diff for secrets, leaks, bugs, and inconsistencies before merging.",
            diffCommand,
            branchless ? false,
          }:
          reviewSkill {
            inherit description diffCommand branchless;
            readyVerdict = "Ready to merge.";
            blockedVerdict = "NOT ready to merge.";
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

          "create-nix-module" = {
            description = "Create a new NX module in nxcore.";
            text = ''
              ## Precondition

              NXCore lives at `~/.config/nx/nxcore`. Before doing anything else, check
              that this directory exists. If it does not, tell the user: "This skill is
              not applicable on this machine - `~/.config/nx/nxcore` does not exist."
              Then stop; do not proceed with any of the steps below.

              All paths in the steps below (e.g. `src/`, `templates/`) are relative to
              `~/.config/nx/nxcore`. Use that as the working root for every file
              operation.

              ## Steps

              1. Check for an existing similar module: `${
                if ripgrepEnabled then
                  ''rg -l "keyword" ~/.config/nx/nxcore/src/''
                else
                  ''grep -rl "keyword" ~/.config/nx/nxcore/src/''
              }`
              2. Find the target group and read 1-2 sibling modules to match conventions.
                 Modules-only inputs (`common`, `linux`, `darwin`, `overlays`, `themes`, `groups`) use `src/INPUT/GROUP/`.
                 The `build` input uses `src/build/modules/GROUP/`.
                 Do not create modules in `config`, `profile`, or `userProfile` - those live in nxconfig.
              3. Copy `~/.config/nx/nxcore/templates/modules/module.nix` to the correct path - never write a module from scratch.
                 - Modules-only: `~/.config/nx/nxcore/src/<INPUT>/<GROUP>/<NAME>.nix`
                 - Build input: `~/.config/nx/nxcore/src/build/modules/<GROUP>/<NAME>.nix`
              4. Set `name`, `group`, and `input` to match the filename, directory, and input path exactly.
              5. Use full store paths in systemd services (`''${pkgs.coreutils}/bin/cat`, not `cat`).
                 Guard `systemd.user.services` with `self.isLinux` in common modules.
              6. Create a companion directory only if config files or secrets are needed:
                 `~/.config/nx/nxcore/src/<INPUT>/<GROUP>/<NAME>.nix.d/`
              7. Tell the user which profile needs updating to enable the module - do not read or edit profile files yourself.
            '';
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
        nx.common.dev.agents.programs = {
          curl = {
            purpose = "making HTTP requests";
            order = 50;
          };
          sqlite3 = {
            purpose = "querying SQLite database files";
            attr = "sqlite";
            available = false;
            order = 60;
          };
          pandoc = {
            purpose = "converting between document formats";
            available = false;
            order = 80;
          };
          gh = {
            purpose = "GitHub operations (PRs, issues, releases)";
            label = "The GitHub CLI";
            alternative = "To query GitHub, use the REST API directly via `curl` (e.g. `curl https://api.github.com/repos/OWNER/REPO/...`).";
            available = false;
            order = 160;
          };
        };

        nx.common.dev.agents.style = lib.mkOrder 100 baseStyle;
        nx.common.dev.agents.instructions = lib.mkOrder 100 baseInstructions;

        nx.common.dev.agents.skills = lib.mkOrder 100 filteredBaseSkills;
        nx.common.dev.agents.agents = lib.mkOrder 100 filteredBaseAgents;
      };

    home =
      {
        config,
        mcpServers,
        enabledAgents,
        preferredAgent,
        ...
      }:
      let
        headerTitle = "Agent Hub";
        titleLen = builtins.stringLength headerTitle;
        styleWidth = titleLen + 4;
        headerWidth = styleWidth + 2;
        orderedAgents =
          if preferredAgent != null && lib.elem preferredAgent enabledAgents then
            [ preferredAgent ] ++ lib.sort (a: b: a < b) (lib.remove preferredAgent enabledAgents)
          else
            lib.sort (a: b: a < b) enabledAgents;
        maxItemLen = lib.foldl' (acc: n: lib.max acc (builtins.stringLength n)) 0 orderedAgents;
        menuWidth = lib.max (builtins.stringLength "Select agent:") (3 + maxItemLen);
        menuOffset = (headerWidth - menuWidth) / 2;
        agentScript =
          if builtins.length orderedAgents == 1 then
            pkgs.writeShellScriptBin "agent" ''
              exec "${builtins.head orderedAgents}"
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
                  ${lib.concatStringsSep " " (map (n: "\"${n}\"") orderedAgents)} > "$_tmpfile" &
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
        assertions = [
          {
            assertion = preferredAgent == null || lib.elem preferredAgent enabledAgents;
            message = "nx.common.dev.agents.preferredAgent must be one of nx.common.dev.agents.enabledAgents!";
          }
        ];

        programs.mcp = {
          enable = true;
          servers = mcpServers;
        };
        home.packages = lib.optional (enabledAgents != [ ]) agentScript;

        home.persistence."${self.persist}" = {
          directories = [
            ".local/share/nx/agents"
          ];
        };
      };
  };
}
