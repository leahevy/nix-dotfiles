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
    purpose = "building and checking Rust code";
    section = "languages";
    order = 30;
    skip = true;
    label = "The Rust toolchain";
    activity = "Rust build or checks";
  };
in
{
  name = "rust";

  group = "dev";
  input = "common";

  description = "Rust compiler and development tooling";

  options = {
    additionalPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional Rust packages to install alongside the toolchain.";
    };
  };

  module = {
    enabled = config: {
      nx.common.dev.agents.programs.cargo = agentProgram;
    };

    disabled = config: {
      nx.common.dev.agents.programs.cargo = agentProgram // {
        available = false;
      };
    };

    home =
      { config, additionalPackages, ... }:
      {
        home.packages =
          with pkgs;
          [
            rustc
            cargo
            clippy
            rustfmt
            rust-analyzer
          ]
          ++ additionalPackages;

        home.persistence."${self.persist}" = {
          directories = [
            ".cargo/registry"
          ];
        };
      };
  };
}
