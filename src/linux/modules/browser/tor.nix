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
  name = "tor";

  group = "browser";
  input = "linux";

  settings = {
    persistCache = false;
  };

  module = {
    linux.home = config: {
      home.packages = with pkgs; [
        tor-browser
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".tor project"
        ]
        ++ lib.optionals self.settings.persistCache [
          ".cache/tor project"
        ];
      };
    };
  };
}
