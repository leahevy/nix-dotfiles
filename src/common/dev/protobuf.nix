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
  name = "protobuf";

  group = "dev";
  input = "common";

  settings = {
    useLatest = false;
  };

  module = {
    home = config: {
      home.packages =
        if self.settings.useLatest then
          (with pkgs; [
            protobuf
          ])
        else
          (with pkgs; [
            protobuf
          ]);
    };
  };
}
