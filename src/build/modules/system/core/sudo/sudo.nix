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
  name = "sudo";
  group = "core";
  input = "build";
  namespace = "system";

  settings = {
    mailNotifications = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      security.sudo.extraConfig = ''
        Defaults lecture = never
        ${lib.optionalString self.settings.mailNotifications ''
          Defaults mail_badpass
          Defaults mail_no_user
          Defaults mail_no_host
          Defaults mail_no_perms
          Defaults mailto = root
          Defaults mailsub = "Security Alert: %h sudo attempt by %u"
          Defaults mailerpath = /run/wrappers/bin/sendmail
        ''}
      '';
    };
}
