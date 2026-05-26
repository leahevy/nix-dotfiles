{
  config,
  pkgs,
  lib,
  variables,
  helpers,
  nx-repositories,
  ...
}:

{
  imports = [
    ./live-common.nix
  ];
}
