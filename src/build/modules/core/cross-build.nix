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
  name = "cross-build";
  group = "core";
  input = "build";

  description = "Enable cross-architecture builds via QEMU binfmt emulation";

  module = {
    linux.system = config: {
      boot.binfmt.emulatedSystems =
        if self.isX86_64 then
          [ "aarch64-linux" ]
        else if self.isAARCH64 then
          [ "x86_64-linux" ]
        else
          [ ];
    };
  };
}
