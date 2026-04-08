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

  coreRepoIsoUrl = "https://github.com/leahevy/nix-dotfiles";

  allowedUnfreePackages = [ ];

  persist = "/persist";

  httpConnections = 15;

  unstablePackages = [ ];
  unstableLinuxPackages = [ ];
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
