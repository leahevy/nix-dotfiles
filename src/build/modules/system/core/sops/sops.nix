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
  name = "sops";

  configuration =
    context@{ config, options, ... }:
    {
      sops = {
        defaultSopsFile = self.config.secretsPath "host-secrets.yaml";
        age.keyFile = "${self.variables.persist.system}/etc/sops/age/keys.txt";
      };
    };
}
