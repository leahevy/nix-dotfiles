{ lib, ... }:
{
  cudaArchitectures = [ ];

  latestLinuxOverride = null; # e.g. "linux_6_16";
  ltsLinuxOverride = null; # e.g. "linux_6_12";

  current-release = "25.11";
  state-version = "25.11";

  experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix-implementation = "nix"; # "nix" | "lix"

  home-manager-backup-extension = "nix-rebuild.backup";

  coreRepoURL = "https://github.com/leahevy/nix-dotfiles.git";
  configRepoURL = "";

  isoManagementSSHKey = null;

  disallowSymlinks = true;

  allowedUnfreePackages = [ ];

  releaseTransitionInsecurePackages = [
    "docker-28.5.2"
    "electron-39.8.10"
  ];

  persist = "/persist";

  httpConnections = 15;
  maxSubstitutionJobs = 3;
  connectTimeout = 60;
  stalledDownloadTimeout = 120;

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

  defaultTheme = "season";

  allowedCountriesByGeoIP = [ "de" ];
}
