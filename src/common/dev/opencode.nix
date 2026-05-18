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
  name = "opencode";

  group = "dev";
  input = "common";

  options = {
    instructions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf bulletItemType);
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
