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
  name = "nix-startify-logo";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.startify.settings.custom_header = lib.mkForce [
        ""
        ""
        "       ◢██◣   ◥███◣  ◢██◣"
        "       ◥███◣   ◥███◣◢███◤"
        "        ◥███◣   ◥██████◤"
        "    ◢█████████████████◤   ◢◣"
        "   ◢██████████████████◣  ◢██◣"
        "        ◢███◤      ◥███◣◢███◤"
        "       ◢███◤        ◥██████◤"
        "◢█████████◤          ◥█████████◣"
        "◥█████████◣          ◢█████████◤"
        "    ◢██████◣        ◢███◤"
        "   ◢███◤◥███◣      ◢███◤"
        "   ◥██◤  ◥██████████████████◤"
        "    ◥◤   ◢█████████████████◤"
        "        ◢██████◣   ◥███◣"
        "       ◢███◤◥███◣   ◥███◣"
        "       ◥██◤  ◥███◣   ◥██◤"
        ""
      ];
    };
}
