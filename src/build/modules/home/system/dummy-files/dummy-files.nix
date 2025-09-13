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
  name = "dummy-files";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/gnome-initial-setup-done".text = "yes";
      home.file.".hushlogin".text = "";
      home.file.".sudo_as_admin_successful".text = "";
    };
}
