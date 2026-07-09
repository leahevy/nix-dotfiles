args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "icons";
  description = "Shared icon source derivations for app icons";

  group = "desktop";
  input = "linux";

  options = {
    dashboardIcons = lib.mkOption {
      type = lib.types.package;
      description = "The homarr-labs/dashboard-icons source derivation for app icon paths";
    };
  };

  module = {
    init = config: {
      nx.linux.desktop.icons.dashboardIcons = pkgs.fetchFromGitHub {
        owner = "homarr-labs";
        repo = "dashboard-icons";
        rev = "f222c55843b888a82e9f2fe2697365841cbe6025";
        hash = "sha256-VOWQh8ZadsqNInoXcRKYuXfWn5MK0qJpuYEWgM7Pny8=";
      };
    };
  };
}
