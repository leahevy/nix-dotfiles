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
  namespace = "home";

  settings = {
    useLatest = false;
  };

  configuration =
    context@{ config, options, ... }:
    {
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
}
