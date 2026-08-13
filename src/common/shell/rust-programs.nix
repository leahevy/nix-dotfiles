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
      notes = [
        "`rg` searches recursively by default, so a plain `rg PATTERN` or `rg PATTERN .` already walks the tree, no recursion flag needed."
        "`-r` is `--replace`, not recursive. Never pass `-r` to make `rg` recurse, it rewrites match output instead and mangles results. There is no recursion flag to add."
      ];
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
