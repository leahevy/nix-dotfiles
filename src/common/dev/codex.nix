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
      default = "gpt-5.2";
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
  };

  module = {
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
        ...
      }:
      let
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

        builtInRules = {
          git-remote = ''
            prefix_rule(
              pattern = ["git", "remote"],
              decision = "forbidden",
              justification = "Do not inspect or print git remote URLs from Codex.",
              match = [
                "git remote -v",
                "git remote show origin",
              ],
            )

            prefix_rule(
              pattern = ["git", "ls-remote"],
              decision = "forbidden",
              justification = "No remote lookups from Codex.",
              match = ["git ls-remote origin"],
            )
          '';
        };

        builtInInstruction = [ ];

        customInstructions = lib.concatStringsSep "\n\n" (builtInInstruction ++ defaultInstructions);

        codexRulesFiles = builtins.listToAttrs (
          map (name: {
            name = ".codex/rules/${name}.rules";
            value = {
              text = (builtInRules.${name} or additionalRules.${name});
            };
          }) (builtins.attrNames (builtInRules // additionalRules))
        );

        codexSettings = {
          model = defaultModel;
          model_reasoning_effort = defaultReasoningEffort;
          personality = defaultPersonality;

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
            skill_mcp_dependency_install = false;
          };

          permissions.hardened.filesystem = {
            ":project_roots" = {
              "." = "read";
              "**/.env*" = "none";
              "**/*.pem" = "none";
              "**/*.key" = "none";
              "**/id_rsa" = "none";
              "**/*secret*" = "none";
            };

            "/etc" = "none";
            "/proc" = "none";
            "/sys" = "none";
            "/run" = "none";
          };

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

        home.file = codexRulesFiles // {
          ".codex/config.toml".source = codexConfigToml;
        };

        home.persistence."${self.persist}" = {
          directories = [ ".codex" ];
        };
      };
  };
}
