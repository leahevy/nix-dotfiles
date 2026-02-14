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
  name = "pass";

  group = "proton";
  input = "common";
  namespace = "home";

  unfree = [
    "proton-authenticator"
    "proton-pass-cli"
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.packages =
        (with pkgs; [
          proton-pass
          proton-authenticator
        ])
        ++ (with pkgs-unstable; [
          proton-pass-cli
        ]);
    };
}
