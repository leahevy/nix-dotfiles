args@{
  lib,
  pkgs,
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
        isHeadless = !(helpers.hasDesktop self);
      in
      {
        nx.linux.monitoring.journal-watcher.ignorePatterns =
          if !isHeadless then
            [
              {
                tag = "sudo";
                all = true;
              }
            ]
          else
            [
              {
                tag = "sudo";
                string = "a password is required";
                all = true;
              }
              {
                tag = "sudo";
                string = "pam_unix\\(sudo:auth\\): conversation failed";
                all = true;
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
