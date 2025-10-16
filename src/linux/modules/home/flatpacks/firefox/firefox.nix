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
  name = "firefox";

  group = "flatpacks";
  input = "linux";
  namespace = "home";

  defaults = {
    package = "org.mozilla.firefox";
  };

  submodules = {
    linux = {
      software = {
        flatpack = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      dataDir = "${self.user.home}/.local/share/nx-flatpack";
      packageFile = "${dataDir}/${self.settings.package}.flatpack";
    in
    {
      home.file."${packageFile}".text = "";
    };
}
