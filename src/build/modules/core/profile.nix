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
  name = "profile";

  group = "core";
  input = "build";

  rawOptions = {
    nx.profile.host = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "The host object of the selected profile";
    };
    nx.profile.user = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "The user object of the selected profile";
    };
    nx.profile.isStandalone = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the profile is standalone";
    };
    nx.profile.isIntegrated = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the profile is integrated";
    };
    nx.profile.isLinux = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the profile is on Linux";
    };
    nx.profile.isDarwin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the profile is on Darwin";
    };
    nx.profile.isX86_64 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the profile is on x86_64";
    };
    nx.profile.isAARCH64 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the profile is on aarch64";
    };
    nx.profile.isNixOS = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the profile is on NixOS";
    };
  };

  module = {
    enabled = config: {
      nx.profile.user = self.user;
      nx.profile.host = self.host;
      nx.profile.isStandalone = self.user.isStandalone or false;
      nx.profile.isIntegrated = self.user.isIntegrated or false;
      nx.profile.isLinux = self.isLinux;
      nx.profile.isDarwin = self.isDarwin;
      nx.profile.isX86_64 = self.isX86_64;
      nx.profile.isAARCH64 = self.isAARCH64;
      nx.profile.isNixOS = (self.user.isIntegrated or false) && self.isLinux;
    };
  };
}
