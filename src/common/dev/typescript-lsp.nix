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
    purpose = "TypeScript type-checking";
    requiresFiles = [ "tsconfig.json" ];
    section = "languages";
    order = 10;
    skip = true;
    label = "The TypeScript compiler";
    activity = "TypeScript type-checking";
    alsoAvoid = [ "npx tsc" ];
  };
in
{
  name = "typescript-lsp";

  group = "dev";
  input = "common";

  module = {
    enabled = config: {
      nx.common.dev.agents.programs.tsc = agentProgram;
    };

    disabled = config: {
      nx.common.dev.agents.programs.tsc = agentProgram // {
        available = false;
      };
    };

    home = config: {
      home.packages = with pkgs; [
        typescript
        typescript-language-server
      ];
    };
  };
}
