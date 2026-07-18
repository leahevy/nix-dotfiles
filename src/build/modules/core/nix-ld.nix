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
  name = "nix-ld";
  group = "core";
  input = "build";

  disableOnTestingVM = true;

  module = {
    system = config: {
      programs.nix-ld.enable = true;
    };

    ifEnabled.linux.security.aide = {
      enabled = config: {
        nx.linux.security.aide.linkTargets =
          lib.optionalAttrs self.isX86_64 {
            "/lib64/ld-linux-x86-64.so.2" = "";
          }
          // lib.optionalAttrs self.isAARCH64 {
            "/lib/ld-linux-aarch64.so.1" = "";
          };
      };
    };
  };
}
