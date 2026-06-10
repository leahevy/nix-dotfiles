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

  module = {
    enabled =
      config:
      let
        isHeadless = (self.host.settings.system.desktop or null) == null;
      in
      {
        nx.linux.monitoring.journal-watcher.ignorePatterns = [
          {
            tag = "sudo";
            all = true;
          }
        ];
        nx.linux.monitoring.journal-watcher.highlightPatterns = lib.optionals isHeadless [
          {
            tag = "sudo";
            string = "3 incorrect password attempts";
            all = true;
            mapping = {
              priority = "warn";
              title = "sudo: authentication failure";
            };
          }
        ];
      };

    system = config: {
      security.sudo.extraConfig = ''
        Defaults lecture = never
        Defaults passwd_tries = 3
      '';
    };
  };
}
