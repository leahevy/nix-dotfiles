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
    purpose = "building and checking Go code";
    section = "languages";
    order = 20;
    skip = true;
    label = "The Go toolchain";
    activity = "Go build or checks";
  };
in
{
  name = "go";

  group = "dev";
  input = "common";

  description = "Go compiler and development tooling";

  options = {
    additionalPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional Go packages to install alongside the toolchain.";
    };
  };

  module = {
    enabled = config: {
      nx.common.dev.agents.programs.go = agentProgram;
    };

    disabled = config: {
      nx.common.dev.agents.programs.go = agentProgram // {
        available = false;
      };
    };

    home =
      { config, additionalPackages, ... }:
      {
        home.sessionVariables = {
          GOPATH = "${self.user.home}/.local/share/go";
        };

        home.packages =
          with pkgs;
          [
            go
            gopls
            delve
            go-tools
            gotools
          ]
          ++ additionalPackages;

        home.persistence."${self.persist}" = {
          directories = [
            ".cache/go-build"
            ".local/share/go"
          ];
        };
      };
  };
}
