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
  configuration =
    context@{ config, options, ... }:
    {
      home.packages =
        with pkgs;
        [
          poetry
        ]
        ++ (if self.isLinux then with pkgs; [ conda ] else [ ]);
    };
}
