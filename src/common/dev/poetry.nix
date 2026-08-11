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
    purpose = "Python dependency and environment management";
    section = "languages";
    order = 60;
    skip = true;
    requiresFiles = [ "poetry.lock" ];
  };
in
{
  name = "poetry";

  group = "dev";
  input = "common";

  module = {
    enabled = config: {
      nx.common.dev.agents.programs.poetry = agentProgram;
    };

    disabled = config: {
      nx.common.dev.agents.programs.poetry = agentProgram // {
        available = false;
      };
    };

    home = config: {
      home.packages = with pkgs; [
        poetry
      ];
    };
  };
}
