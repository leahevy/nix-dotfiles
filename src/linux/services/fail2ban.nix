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
  name = "fail2ban";

  group = "services";
  input = "linux";

  module = {
    linux.system = config: {
      services.fail2ban = {
        enable = true;
      };

      environment.persistence."${self.persist}" = {
        directories = [
          "/var/lib/fail2ban"
        ];
      };
    };
  };
}
