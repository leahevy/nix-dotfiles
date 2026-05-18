args@{
  lib,
  pkgs,
  pkgs-unstable,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  isValidBullet =
    x:
    if lib.isString x then
      true
    else if lib.isList x && x != [ ] then
      builtins.all isValidBullet x
    else
      false;
  bulletItemType = lib.types.mkOptionType {
    name = "bulletItem";
    description = "string or non-empty nested list of strings";
    check = isValidBullet;
    merge = lib.options.mergeOneOption;
  };
in
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
      type = lib.types.attrsOf (lib.types.listOf bulletItemType);
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

  module = {
    enabled =
      config:
      let
        disableTestData = config.nx.common.dev.agents.disableTestData;
        difftasticEnabled =
          (config.programs.difftastic.enable or false) && (config.programs.difftastic.git.enable or false);

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
        };

        prePushReviewSkill =
          {
            description ? "Review the outgoing diff for secrets and privacy leaks before pushing.",
            diffCommand,
          }:
          {
            description = "${description} (${diffCommand})";
            text = ''
              1) Confirm the branch has an upstream tracking branch:
                 `git rev-parse --abbrev-ref --symbolic-full-name @{u}`

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
          }:
          {
            description = "${description} (${diffCommand})";
            text = ''
              1) Determine the target branch you will merge into (e.g. `main`, `master`, `develop`).
                 If it's unclear, ask the user which target branch to review against.

              2) Choose the remote for the target branch.
                 Default to `origin` unless the user says otherwise.

              3) Review the diff:
                 `${diffCommand}`

              4) Review focus:
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
          };

          review-pre-push-workdir = prePushReviewSkill {
            diffCommand = "git diff${lib.optionalString difftasticEnabled " --no-ext-diff"}";
          };

          review-merge-request-head = mergeRequestReviewSkill {
            diffCommand = "git diff${lib.optionalString difftasticEnabled " --no-ext-diff"} TARGET_REMOTE/TARGET_BRANCH...HEAD";
          };

          review-merge-request-cached = mergeRequestReviewSkill {
            diffCommand = "git diff${lib.optionalString difftasticEnabled " --no-ext-diff"} --cached";
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
        ...
      }:
      {
        programs.mcp = {
          enable = true;
          servers = mcpServers;
        };
      };
  };
}
