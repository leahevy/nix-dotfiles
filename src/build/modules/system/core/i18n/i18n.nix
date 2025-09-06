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
let
  host = self.host;
in
{
  configuration =
    context@{ config, options, ... }:
    {
      time.timeZone = host.settings.system.timezone;
      i18n.defaultLocale = host.settings.system.locale.main;

      i18n.extraLocaleSettings = {
        LC_ADDRESS = host.settings.system.locale.extra;
        LC_IDENTIFICATION = host.settings.system.locale.extra;
        LC_MEASUREMENT = host.settings.system.locale.extra;
        LC_MONETARY = host.settings.system.locale.extra;
        LC_NAME = host.settings.system.locale.extra;
        LC_NUMERIC = host.settings.system.locale.extra;
        LC_PAPER = host.settings.system.locale.extra;
        LC_TELEPHONE = host.settings.system.locale.extra;
        LC_TIME = host.settings.system.locale.extra;
      };
    };
}
