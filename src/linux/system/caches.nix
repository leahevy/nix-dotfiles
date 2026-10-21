args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  autoHosts = lib.filterAttrs (
    _: hostCfg:
    (hostCfg.remote.exposedServices.harmonia or null) != null
    && (hostCfg.hostname or null) != (self.host.hostname or null)
  ) (self.nixOSHosts or { });
in
{
  name = "caches";

  group = "system";
  input = "linux";

  options = {
    servers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "Base URL of the binary cache (e.g. https://cache.example.com).";
            };
            signingKeyPublicKey = lib.mkOption {
              type = lib.types.str;
              description = "Nix store signing public key string (name:base64).";
            };
          };
        }
      );
      default = [ ];
      description = "Additional binary cache servers to add as substituters.";
    };

  };

  module = {
    system =
      {
        config,
        servers,
        ...
      }:
      let
        autoSubstituters = lib.concatMap (
          hostCfg:
          let
            svc = hostCfg.remote.exposedServices.harmonia;
            domain = hostCfg.remote.baseDomain or null;
          in
          lib.optional (domain != null) "https://${svc.subdomain}.${domain}"
        ) (lib.attrValues autoHosts);

        autoKeys = lib.concatMap (
          hostCfg:
          let
            domain = hostCfg.remote.baseDomain or null;
          in
          lib.optional (domain != null) hostCfg.remote.exposedServices.harmonia.signingKeyPublicKey
        ) (lib.attrValues autoHosts);

        allSubstituters = autoSubstituters ++ map (s: s.url) servers;
        allKeys = autoKeys ++ map (s: s.signingKeyPublicKey) servers;
      in
      lib.mkIf (allSubstituters != [ ]) {
        nix.settings.substituters = allSubstituters;
        nix.settings.trusted-public-keys = allKeys;
      };
  };
}
