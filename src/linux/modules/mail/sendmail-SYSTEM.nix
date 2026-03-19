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
  name = "sendmail";

  group = "mail";
  input = "linux";
  namespace = "system";

  settings = {
    auth = true;
    tls = true;
    from = null;
    to = null;
    host = null;
    port = 587;
    user = null;
  };

  assertions = [
    {
      assertion = self.settings.from != null;
      message = "from is required";
    }
    {
      assertion = self.settings.host != null;
      message = "host is required";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      sops.secrets."smtp-password" = {
        format = "binary";
        sopsFile = self.config.secretsPath "smtp-password";
        mode = "0400";
        owner = "root";
        group = "root";
      };

      programs.msmtp = {
        enable = true;

        accounts.default = {
          auth = self.settings.auth;
          tls = self.settings.tls;
          from = self.settings.from;
          host = self.settings.host;
          port = self.settings.port;
          user = if self.settings.user != null then self.settings.user else self.settings.from;
          passwordeval = "cat ${config.sops.secrets."smtp-password".path}";
        };

        defaults = {
          aliases = "/etc/aliases";
        };
      };

      environment.etc = {
        "aliases" = {
          text =
            let
              toAddress = if self.settings.to != null then self.settings.to else self.user.email;
            in
            ''
              postmaster: ${toAddress}
              root: ${toAddress}
              ${self.user.username}: ${toAddress}
            '';
          mode = "0644";
        };
      };
    };
}
