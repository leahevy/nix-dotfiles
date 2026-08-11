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
  agentPrograms = {
    rg = {
      purpose = "fast recursive text search";
      attr = "ripgrep";
      order = 30;
    };
    fd = {
      purpose = "fast file finding";
      order = 40;
    };
  };
in
{
  name = "rust-programs";

  group = "shell";
  input = "common";

  module = {
    enabled = config: {
      nx.common.dev.agents.programs = agentPrograms;
    };

    disabled = config: {
      nx.common.dev.agents.programs = lib.mapAttrs (_: p: p // { available = false; }) agentPrograms;
    };

    home = config: {
      home.packages = with pkgs; [
        bat
        fd
        ripgrep
      ];

      home.shellAliases = {
        cat = "bat";
      };
    };
  };
}
