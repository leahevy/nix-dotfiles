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
  name = "opencode";

  group = "dev";
  input = "common";

  options = {
    instructions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf helpers.optionsHelpers.recursiveStringListType);
      default = { };
      description = "OpenCode-specific instructions.";
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
      description = "OpenCode-specific skills.";
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
      description = "OpenCode-specific custom agents.";
    };
  };

  submodules = {
    common = {
      dev = [ "agents" ];
    };
  };

  module = {
    enabled =
      config:
      let
        baseInstructions = { };
        baseSkills = { };
        baseAgents = { };
      in
      {
        nx.common.dev.opencode.instructions = lib.mkOrder 200 baseInstructions;

        nx.common.dev.opencode.skills = lib.mkOrder 200 baseSkills;
        nx.common.dev.opencode.agents = lib.mkOrder 200 baseAgents;
      };

    home =
      {
        config,
        instructions,
        skills,
        agents,
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

        mergedAgents = sharedAgents.agents // agents;

        opencodeSkillFiles = lib.mapAttrs' (name: value: {
          name = ".config/opencode/skills/${name}/SKILL.md";
          value = {
            text =
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
              ''
                ---
                name: ${builtins.toJSON name}
                description: ${builtins.toJSON payload.description}
                ---

                ${payload.text}
              '';
          };
        }) mergedSkills;

        opencodeAgentFiles = lib.mapAttrs' (name: value: {
          name = ".config/opencode/agents/${name}.md";
          value = {
            text = ''
              # ${name}

              ${value.text}
            '';
          };
        }) mergedAgents;
      in
      {
        programs.opencode = {
          enable = true;
          enableMcpIntegration = true;
          settings.permission.skill."*" = lib.mkDefault "allow";
        };

        home.file =
          opencodeSkillFiles
          // opencodeAgentFiles
          // {
            ".config/opencode/AGENTS.md".text = mergedContext;
          };

        home.persistence."${self.persist}" = {
          directories = [ ".config/opencode" ];
        };
      };
  };
}
