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
    order = 50;
    skip = true;
    requiresFiles = [ "uv.lock" ];
  };
in
{
  name = "uv";

  group = "dev";
  input = "common";

  module = {
    enabled = config: {
      nx.common.dev.agents.programs.uv = agentProgram;
    };

    disabled = config: {
      nx.common.dev.agents.programs.uv = agentProgram // {
        available = false;
      };
    };

    home = config: {
      home.packages = with pkgs; [
        uv
      ];
    };
  };
}
