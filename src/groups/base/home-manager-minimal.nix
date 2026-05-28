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
  name = "home-manager-minimal";
  description = "Home Manager minimal base group";

  group = "base";
  input = "groups";

  submodules = {
    common = {
      nvim = {
        nixvim = true;
      };
      git = {
        git = {
          disableSSHRewrites = true;
        };
      };
      tmux = [ "tmux" ];
      shell = [
        "starship"
        "go-programs"
      ];
      python = [ "python" ];
    };
    groups.shell = [ "shell" ];
  };
}
