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
  name = "jujutsu";

  group = "dev";
  input = "common";

  submodules = {
    common = {
      git = [ "git" ];
    };
  };

  on = {
    home = config: {
      programs.jujutsu = {
        enable = true;
        ediff = false;
        settings =

          let
            gpgKey =
              let
                candidate = helpers.ifSet (self.settings.gpg or null) (self.user.gpg or null);
              in
              if candidate != null && candidate != "" then candidate else null;
          in
          {
            user = {
              name = helpers.ifSet (self.settings.name or null) self.user.fullname;
              email = helpers.ifSet (self.settings.email or null) self.user.email;
            };
            ui = {
              show-cryptographic-signatures = true;
              default-command = "log";
            };
            git = {
              push-new-bookmarks = true;
            };
            aliases = {
              init = [
                "git"
                "init"
                "--colocate"
              ];
              pull = [
                "git"
                "fetch"
              ];
              push = [
                "git"
                "push"
                "--allow-new"
              ];
            };
          }
          // lib.optionalAttrs (gpgKey != null) {
            signing = {
              behavior = "own";
              backend = "gpg";
              key = gpgKey;
            };
          };
      };
    };
  };
}
