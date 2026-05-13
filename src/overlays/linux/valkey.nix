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
  name = "valkey";
  group = "linux";
  input = "overlays";

  module = {
    linux.overlays = [
      (final: prev: {
        valkey = prev.valkey.overrideAttrs (
          old:
          let
            extraSkipUnits = [
              "integration/dual-channel-replication"
              "unit/cluster/replica-migration"
            ];
            skipFlags = lib.concatMapStringsSep " " (u: "--skipunit ${u}") extraSkipUnits;
          in
          {
            checkPhase =
              builtins.replaceStrings [ "./runtest \\" ] [ "./runtest ${skipFlags} \\" ]
                old.checkPhase;
          }
        );
      })
    ];
  };
}
