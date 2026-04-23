{ lib, ... }:
{
  cudaArchitectures = [ ];

  latestLinuxOverride = null; # e.g. "linux_6_16";
  ltsLinuxOverride = null; # e.g. "linux_6_12";

  state-version = "25.05";

  experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix-implementation = "lix"; # "nix" | "lix"

  coreRepoIsoUrl = "https://github.com/leahevy/nix-dotfiles";
  coreRepoInstallUrl = "git@github.com:leahevy/nix-dotfiles.git";
  configRepoIsoUrl = "";
  configRepoInstallUrl = "";

  allowedUnfreePackages = [ ];

  persist = "/persist";

  httpConnections = 15;

  unstablePackages = [
    "codex"
    "claude-code"
  ];
  unstableLinuxPackages = [ "protonmail-desktop" ];
  unstableDarwinPackages = [ ];

  nx.config = {
    minEnabledModules = 20;
    security = {
      commitVerification = {
        nxcore = "last"; # "all" | "last" | "none"
        nxconfig = "last"; # "all" | "last" | "none"
      };
    };
  };

  defaultTheme = "green";
}
