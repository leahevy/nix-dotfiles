{ lib, ... }:
{
  latestLinux = "linux_6_16";
  ltsLinux = "linux_6_12";
  hardenedLinux = "linux_6_12_hardened";

  state-version = "25.05";

  experimental-features = [
    "nix-command"
    "flakes"
  ];

  coreRepoIsoUrl = "https://github.com/leahevy/nix-dotfiles";

  allowedUnfreePackages = [ ];

  persist = {
    system = "/persist";
    home = "/persist/home";
  };

  httpConnections = 15;

  nx.config = {
    security = {
      commitVerification = {
        nxcore = "last"; # "all" | "last" | "none"
        nxconfig = "last"; # "all" | "last" | "none"
      };
    };
  };

  defaultTheme = "green";

  defaultDesktop = {
    primary = "kde";
    secondary = "kde";
  };
}
