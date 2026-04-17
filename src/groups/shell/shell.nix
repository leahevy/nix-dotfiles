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
  name = "shell";
  description = "Shell group module";

  group = "shell";
  input = "groups";

  submodules = {
    common.shell = [
      "bash"
      "zsh"
      "fish"
      "session"
    ];
  };
}
