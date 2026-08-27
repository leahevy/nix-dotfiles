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
        "`-r` is `--replace`, not recursive. Never use `-r` or `--replace` with `rg` for any purpose; both rewrite match output instead of searching. There is no recursion flag; `rg` is already recursive."
        "For alternation use bare `|` (e.g. `rg 'foo|bar'`), never `\\|`; `\\|` is grep syntax and in rg matches a literal pipe character, silently finding nothing."
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
