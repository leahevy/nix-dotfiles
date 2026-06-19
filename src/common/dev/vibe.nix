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
  name = "vibe";
  description = "Mistral Vibe CLI coding assistant";

  group = "dev";
  input = "common";

  unfree = [
    "textual-speedups"
  ];

  options = {
    instructions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf helpers.optionsHelpers.recursiveStringListType);
      default = { };
      description = "Mistral Vibe-specific instructions merged on top of shared agent instructions.";
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
      description = "Mistral Vibe-specific skills merged with shared agent skills.";
    };

    defaultAgent = lib.mkOption {
      type = lib.types.enum [
        "default"
        "plan"
        "accept-edits"
        "auto-approve"
      ];
      default = "default";
      description = "Default agent mode controlling tool approval behavior.";
    };
  };

  submodules = {
    common = {
      dev = [ "agents" ];
    };
  };

  module = {
    overlays = [
      (final: prev: {
        mistral-vibe =
          let
            ourExt = _: pyPrev: {
              jsonpath-python = pyPrev.jsonpath-python.overridePythonAttrs (_: {
                doCheck = false;
              });
            };
            python3 = prev.python3 // {
              override =
                args:
                prev.python3.override (
                  if args ? packageOverrides then
                    args // { packageOverrides = lib.composeExtensions ourExt args.packageOverrides; }
                  else
                    args // { packageOverrides = ourExt; }
                );
            };
          in
          prev.mistral-vibe.override { inherit python3; };
      })
    ];

    home =
      {
        config,
        instructions,
        skills,
        defaultAgent,
        ...
      }:
      let
        sharedAgents = config.nx.common.dev.agents;
        renderInstructions = self.common.dev.agents.exports.renderInstructions;

        mergedInstructions = helpers.deepMergeComplex {
          base = sharedAgents.instructions;
          override = instructions;
        };
        mergedContext = renderInstructions mergedInstructions;

        mergedSkills = sharedAgents.skills // skills;

        mcpServersList = lib.mapAttrsToList (
          name: cfg:
          {
            inherit name;
          }
          // lib.optionalAttrs (!(cfg ? transport)) { transport = "stdio"; }
          // cfg
          // {
            env = {
              HOME = self.user.home;
            }
            // (cfg.env or { });
          }
        ) sharedAgents.mcpServers;

        nixSettings = (pkgs.formats.json { }).generate "vibe-nix-settings.json" {
          default_agent = defaultAgent;
          enable_telemetry = false;
          enable_auto_update = false;
          skill_paths = [ "${self.user.home}/.vibe/skills" ];
          mcp_servers = mcpServersList;
        };

        python = pkgs.python3.withPackages (p: [ p.tomli-w ]);

        mergeScript = pkgs.writeScript "vibe-merge-config" ''
          #!${python}/bin/python3
          import json, os, tomllib, tomli_w

          cfg_path = os.path.join(os.environ['HOME'], '.vibe', 'config.toml')

          with open('${nixSettings}') as f:
              nix = json.load(f)

          if os.path.islink(cfg_path):
              os.unlink(cfg_path)

          if os.path.exists(cfg_path):
              with open(cfg_path, 'rb') as f:
                  existing = tomllib.load(f)
              merged = existing | nix
          else:
              merged = nix

          with open(cfg_path, 'wb') as f:
              tomli_w.dump(merged, f)
        '';

        skillStoreFiles = lib.mapAttrs (
          name: value:
          let
            payload =
              if lib.isString value then
                {
                  description = "Custom skill ${name}.";
                  text = value;
                }
              else
                {
                  description = value.description or "Custom skill ${name}.";
                  text = value.text;
                };
          in
          pkgs.writeText "vibe-skill-${name}.md" ''
            ---
            name: ${builtins.toJSON name}
            description: ${builtins.toJSON payload.description}
            ---

            ${payload.text}
          ''
        ) mergedSkills;

        skillsScript = pkgs.writeShellScript "vibe-materialize-skills" ''
          skills_dir="$HOME/.vibe/skills"
          mkdir -p "$skills_dir"
          find "$skills_dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -delete
          find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -empty -delete

          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: storeFile: ''
              mkdir -p "$skills_dir/${name}"
              cp -f ${storeFile} "$skills_dir/${name}/SKILL.md"
            '') skillStoreFiles
          )}
        '';
      in
      {
        home.packages = [ pkgs.mistral-vibe ];

        home.file = lib.mkIf (mergedContext != "") {
          ".vibe/AGENTS.md".text = mergedContext;
        };

        home.activation = {
          mergeVibeConfig = (self.hmLib config).dag.entryAfter [ "writeBoundary" ] ''
            run mkdir -p "$HOME/.vibe"
            run ${mergeScript} || true
          '';
          materializeVibeSkills = (self.hmLib config).dag.entryAfter [ "writeBoundary" ] ''
            run ${skillsScript} || true
          '';
        };

        home.persistence."${self.persist}" = {
          directories = [ ".vibe" ];
        };
      };
  };
}
