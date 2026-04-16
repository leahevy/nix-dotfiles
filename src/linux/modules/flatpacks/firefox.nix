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

  settings = {
    package = "org.mozilla.firefox";
  };

  submodules = {
    linux = {
      software = {
        flatpack = true;
      };
    };
  };

  module = {
    home =
      config:
      let
        dataDir = "${self.user.home}/.local/share/nx-flatpack";
        packageFile = "${dataDir}/${self.settings.package}.flatpack";
      in
      {
        home.file."${packageFile}".text = "";
      };
  };
}
