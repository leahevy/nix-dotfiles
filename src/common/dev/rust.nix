args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
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
