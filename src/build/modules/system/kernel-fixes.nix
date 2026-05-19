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
  name = "kernel-fixes";

  group = "system";
  input = "build";

  rawOptions = {
    nx.nixos.kernelFixes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Kernel fix CVE identifiers applied to this system due to version constraints.";
    };
  };

  module =
    let
      kernelFixes = {
        # Mitigates: Fragnesia, Dirty Frag
        "CVE-2026-46300" = {
          when =
            major: minor: patch:
            major == 6 && minor == 12 && patch < 91;
          apply = {
            boot.blacklistedKernelModules = [
              "esp4"
              "esp6"
              "rxrpc"
            ];
            boot.extraModprobeConfig = ''
              install esp4 ${pkgs.coreutils}/bin/false
              install esp6 ${pkgs.coreutils}/bin/false
              install rxrpc ${pkgs.coreutils}/bin/false
            '';
          };
        };
      };

      fixActive =
        config: fix:
        let
          kv = config.boot.kernelPackages.kernel.version;
        in
        fix.when (lib.toInt (lib.versions.major kv)) (lib.toInt (lib.versions.minor kv)) (
          lib.toInt (lib.versions.patch kv)
        );
    in
    {
      enabled =
        config:
        lib.mkMerge (
          lib.mapAttrsToList (
            name: fix: lib.mkIf (fixActive config fix) { nx.nixos.kernelFixes = [ name ]; }
          ) kernelFixes
        );

      system =
        config:
        lib.mkMerge (lib.mapAttrsToList (_: fix: lib.mkIf (fixActive config fix) fix.apply) kernelFixes);
    };
}
