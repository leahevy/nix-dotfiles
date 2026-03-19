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
  name = "msmtp";
  group = "mail-stack";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      mail-stack = {
        accounts = true;
      };
    };
  };

  settings = {
    service = "mail-stack";
  };

  configuration =
    context@{ config, options, ... }:
    let
      accountsConfig = self.getModuleConfig "mail-stack.accounts";
      accounts = accountsConfig.accounts;
    in
    lib.mkIf (accounts != { }) {
      accounts.email.accounts = lib.mapAttrs (accountKey: account: {
        msmtp = {
          enable = true;
          extraConfig = {
            auth = "on";
            from = account.address;
          };
        };
      }) accounts;

      programs.msmtp.enable = true;
    };
}
