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
        "CRITICAL: For alternation always use bare `|` (e.g. `rg 'foo|bar'`), NEVER `\\|`. The `\\|` form is grep syntax; in rg it matches a literal pipe character and silently finds nothing. Using `\\|` will not error - it will just return wrong results."
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
