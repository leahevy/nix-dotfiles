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
{
  name = "codex";

  group = "dev";
  input = "common";

  options = {
    defaultInstructions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Default instructions to use for Codex.";
    };
    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "gpt-5.4";
      description = "Default model to use for Codex.";
    };
    defaultApprovalPolicy = lib.mkOption {
      type = lib.types.enum [
        "untrusted"
        "on-request"
      ];
      default = "untrusted";
      description = "Default approval policy for Codex.";
    };
    defaultReasoningEffort = lib.mkOption {
      type = lib.types.str;
      default = "medium";
      description = "Default reasoning effort level for Codex.";
    };
    defaultPersonality = lib.mkOption {
      type = lib.types.str;
      default = "pragmatic";
      description = "Default personality for Codex.";
    };
    trustedProjects = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of project paths to mark as trusted.";
    };
    untrustedProjects = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of project paths to mark as untrusted.";
    };
    additionalRules = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional Codex rules to merge in.";
    };

    instructions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf helpers.optionsHelpers.recursiveStringListType);
      default = { };
      description = "Codex-specific instructions.";
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
      description = "Codex-specific skills.";
    };
  };

  submodules = {
    common = {
      dev = [ "agents" ];
    };
  };

  module =
    with import (self.file "patterns.nix") { inherit lib self; };
    let
      denyFilesystemDirPaths =
        denyFilesystemDirPathsCommon
        // lib.optionalAttrs self.isLinux denyFilesystemDirPathsLinux
        // lib.optionalAttrs self.isDarwin denyFilesystemDirPathsDarwin;

      denyFilesystemFilePaths =
        denyFilesystemFilePathsCommon
        // lib.optionalAttrs self.isLinux denyFilesystemFilePathsLinux
        // lib.optionalAttrs self.isDarwin denyFilesystemFilePathsDarwin;

      denyFilesystemPaths = denyFilesystemDirPaths // denyFilesystemFilePaths;

      denyReadGlobsFromDirPaths = map (p: "${p}/**") (builtins.attrNames denyFilesystemDirPaths);
      denyReadGlobsFromFilePaths = builtins.attrNames denyFilesystemFilePaths;

      denyReadGlobs = denyReadGlobsFromDirPaths ++ denyReadGlobsFromFilePaths;

      askExecpolicyPatterns =
        askExecpolicyPatternsCommon
        ++ lib.optionals self.isLinux askExecpolicyPatternsLinux
        ++ lib.optionals self.isDarwin askExecpolicyPatternsDarwin;

      askPromptOnlyGlobs =
        askPromptOnlyGlobsCommon
        ++ lib.optionals self.isLinux askPromptOnlyGlobsLinux
        ++ lib.optionals self.isDarwin askPromptOnlyGlobsDarwin;

      askPromptGlobsFromExecpolicyPatterns = map (
        p: "${lib.concatStringsSep " " p} *"
      ) askExecpolicyPatterns;

      askPromptGlobs = askPromptGlobsFromExecpolicyPatterns ++ askPromptOnlyGlobs;

      askRulesStar =
        let
          renderRule = pattern: ''
            prefix_rule(
              pattern = ${builtins.toJSON pattern},
              decision = "prompt",
              justification = "Always ask before running this command.",
            )
          '';
        in
        lib.concatStringsSep "\n\n" (map renderRule askExecpolicyPatterns);
    in
    {
      enabled =
        config:
        let
          preflightProtocol = [
            "Before ANY `functions.apply_patch` call, post a short pre-flight message that includes: (1) the exact symptom being fixed, (2) the suspected root cause, (3) the exact file path(s) you will edit, (4) the expected behaviour change."
            "Before ANY `functions.exec_command` call that is non-trivial (writes, builds/evals/deploys, long-running commands, interpreter invocations even for inspection), post a short pre-flight note describing what you'll run and why."
            "Every pre-flight message must start with: `**Next Action:**`."
            [
              "Every pre-flight message must end with an empty line, then exactly one of:"
              "`Applying the patch now!`"
              "`Running the command \"CMD\" now!`"
            ]
            "Execute the corresponding tool call immediately in the same turn, with no extra assistant text in between."
            "If a patch attempt is interrupted or aborted, explicitly state whether it was applied or not. If you plan to retry the same patch after an objection, discuss and get user agreement first."
          ];

          codexOnlyRules = [
            "Do not run inline Python scripts for code checks or repository analysis. Prefer dedicated tools or manual reasoning; only run scripting languages when explicitly requested or clearly necessary."
            "Always state what you will do before running any edit tool calls."
            "Never auto-accept edits."
            "If `functions.apply_patch` reports `Success. Updated the following files:` for the intended file path, trust that result and do not read the file again just to confirm the patch was applied."
            "When reading a file for the first time in a session, read the whole file with `cat` via `functions.exec_command` (don't use `rg` as a reader). After the initial full read, you may use targeted commands (e.g. `sed -n`, `rg`) to inspect specific parts."
          ];

          denyReadGlobsText = map (g: "`${g}`") denyReadGlobs;
          askBashGlobsText = map (g: "`${g}`") askPromptGlobs;

          baseInstructions = {
            "90 - Codex" = preflightProtocol ++ codexOnlyRules;

            "98 - DENY Read Globs" = [
              (
                [
                  "**DENY**: Never attempt actions that match `DENY_READ_GLOBS` (forbidden, no override). Do not try to work around these restrictions by reading the data another way:"
                ]
                ++ denyReadGlobsText
              )
            ];

            "99 - ASK Bash Globs" = [
              (
                [
                  "**ASK**: Always ask for explicit confirmation before running any Bash command that matches `ASK_BASH_GLOBS`:"
                ]
                ++ askBashGlobsText
              )
            ];
          };
          baseSkills = { };
        in
        {
          nx.common.dev.codex.instructions = lib.mkOrder 200 baseInstructions;

          nx.common.dev.codex.skills = lib.mkOrder 200 baseSkills;
        };

      home =
        {
          config,
          defaultInstructions,
          defaultModel,
          defaultApprovalPolicy,
          defaultReasoningEffort,
          defaultPersonality,
          trustedProjects,
          untrustedProjects,
          additionalRules,
          instructions,
          skills,
          ...
        }:
        let
          agents = config.nx.common.dev.agents;

          gitUrl = (config.programs.git.settings.url or { });
          githubEnforceSSH =
            gitUrl ? "git@github.com:"
            && (
              let
                entry = gitUrl."git@github.com:";
                insteadOf = entry.insteadOf or null;
              in
              if lib.isList insteadOf then
                lib.any (v: lib.hasPrefix "https://github.com/" v) insteadOf
              else
                lib.isString insteadOf && lib.hasPrefix "https://github.com/" insteadOf
            );

          fake-ssh = pkgs.writeShellScriptBin "ssh" "exit 1";
          codex-wrapped = pkgs.symlinkJoin {
            name = "codex-wrapped";
            paths = [ pkgs.codex ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram "$out/bin/codex" \
                --prefix PATH : ${fake-ssh}/bin \
                --set GIT_CONFIG_COUNT 1 \
                --set GIT_CONFIG_KEY_0 "url.https://github.com/.insteadOf" \
                --set GIT_CONFIG_VALUE_0 "git@github.com:"
            '';
          };
          codex-package =
            if githubEnforceSSH && config.nx.linux.security.yubikey.enable then codex-wrapped else pkgs.codex;

          renderInstructions = self.common.dev.agents.exports.renderInstructions;

          mergedInstructions = helpers.deepMergeComplex {
            base = agents.instructions;
            override = instructions;
          };
          instructionsText = renderInstructions mergedInstructions;

          customInstructionsRaw = lib.concatStringsSep "\n\n" defaultInstructions;
          customInstructions = lib.concatStringsSep "\n\n" (
            lib.filter (v: v != null && v != "") [
              instructionsText
              customInstructionsRaw
            ]
          );

          mergedSkills =
            if lib.isAttrs agents.skills && lib.isAttrs skills then
              agents.skills // skills
            else if skills != { } then
              skills
            else
              agents.skills;

          codexSkillContents =
            if lib.isAttrs mergedSkills then
              lib.mapAttrs (
                name: value:
                if lib.isString value then
                  ''
                    ---
                    name: ${builtins.toJSON name}
                    description: ${builtins.toJSON "Custom skill ${name}."}
                    ---

                    ${value}
                  ''
                else if lib.isAttrs value && value ? text && lib.isString value.text then
                  let
                    desc = value.description or "Custom skill ${name}.";
                  in
                  ''
                    ---
                    name: ${builtins.toJSON name}
                    description: ${builtins.toJSON desc}
                    ---

                    ${value.text}
                  ''
                else
                  throw "Codex skill '${name}' must be a string or an attrset { text = \"...\"; description? = \"...\"; }."
              ) mergedSkills
            else
              { };

          codexSkillStoreFiles = lib.mapAttrs (
            name: text: pkgs.writeText "codex-skill-${name}-SKILL.md" text
          ) codexSkillContents;

          codexRulesFiles =
            lib.mapAttrs' (name: text: {
              name = ".codex/rules/${name}.rules";
              value = { inherit text; };
            }) additionalRules
            // {
              ".codex/rules/ask.rules".text = askRulesStar;
            };

          codexSettings = {
            model = defaultModel;
            model_reasoning_effort = defaultReasoningEffort;
            personality = defaultPersonality;

            mcp_servers = config.nx.common.dev.agents.mcpServers;

            analytics.enabled = false;
            feedback.enabled = false;

            profile = "locked_down";

            profiles = {
              locked_down = {
                sandbox_mode = "read-only";
                approval_policy = defaultApprovalPolicy;
                approvals_reviewer = "user";
                allow_login_shell = false;
              };
            };

            default_permissions = "hardened";

            features = {
              skills = true;
              skill_mcp_dependency_install = false;
            };

            permissions.hardened.filesystem = {
              glob_scan_max_depth = 8;

              ":project_roots" = {
                "." = "read";
                "**/.env*" = "none";
                "**/*.pem" = "none";
                "**/*.key" = "none";
                "**/id_rsa" = "none";
                "**/*secret*" = "none";
              };

              "${self.user.home}/.agents/skills" = "read";
              "/etc" = "none";
              "/proc" = "none";
              "/sys" = "none";
              "/run" = "none";
            }
            // denyFilesystemPaths;

            notice = {
              model_migrations = {
                "gpt-5.2" = "gpt-5.4";
              };
            };

            projects =
              lib.recursiveUpdate
                (builtins.listToAttrs (
                  (map (path: {
                    name = path;
                    value = {
                      trust_level = "trusted";
                    };
                  }) trustedProjects)
                  ++ (map (path: {
                    name = path;
                    value = {
                      trust_level = "untrusted";
                    };
                  }) untrustedProjects)
                ))
                {
                  "${self.user.home}" = {
                    trust_level = "untrusted";
                  };
                };
          };

          codexConfigToml = (pkgs.formats.toml { }).generate "codex-config.toml" codexSettings;
        in
        {
          programs.codex = {
            enable = true;
            package = codex-package;
            custom-instructions = lib.mkIf (
              customInstructions != null && customInstructions != ""
            ) customInstructions;
          };

          home.activation.materializeCodexSkills = (self.hmLib config).dag.entryAfter [ "writeBoundary" ] ''
            shopt -s nullglob

            if [[ -d "$HOME/.agents/skills" ]]; then
              run rm -f "$HOME/.agents/skills"/*/SKILL.md || true
              run rmdir "$HOME/.agents/skills"/* 2>/dev/null || true
            fi

            run mkdir -p "$HOME/.agents/skills" || true

            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: storeFile: ''
                run mkdir -p "$HOME/.agents/skills/${name}" || true
                run rm -f "$HOME/.agents/skills/${name}/SKILL.md" || true
                run cp -f ${storeFile} "$HOME/.agents/skills/${name}/SKILL.md" || true
              '') codexSkillStoreFiles
            )}
          '';

          home.file = codexRulesFiles // {
            ".codex/config.toml".source = codexConfigToml;
          };

          home.persistence."${self.persist}" = {
            directories = [ ".codex" ];
          };
        };
    };
}
