args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  agentProgram = {
    purpose = "running project tasks";
    requiresFiles = [
      "justfile"
      "Justfile"
    ];
    order = 140;
  };
in
{
  name = "just";

  group = "dev";
  input = "common";

  module = {
    enabled = config: {
      nx.common.dev.agents.programs.just = agentProgram;
    };

    disabled = config: {
      nx.common.dev.agents.programs.just = agentProgram // {
        available = false;
      };
    };

    home = config: {
      home.packages = with pkgs; [
        just
      ];
    };
  };
}
