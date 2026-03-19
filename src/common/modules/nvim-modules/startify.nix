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
  name = "startify";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.startify = {
        enable = true;
        settings = {
          custom_header = [
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
          change_to_vcs_root = true;
        };
      };
    };
}
