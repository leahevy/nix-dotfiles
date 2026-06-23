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
  name = "samba-utils";
  group = "storage";
  input = "linux";
  description = "CIFS/SMB client utilities and kernel DNS upcall integration for SMB share mounting.";

  submodules = {
    linux.system.request-key = true;
  };

  module = {
    enabled =
      config:
      let
        cifsUpcall = helpers.packageFile args pkgs.cifs-utils.bin "sbin/cifs.upcall";
      in
      {
        nx.linux.system.request-key.rules = [
          "create dns_resolver * * ${cifsUpcall} %k"
          "create cifs.spnego  * * ${cifsUpcall} %k"
        ];
      };

    linux.system = config: {
      environment.systemPackages = [
        pkgs.cifs-utils
        pkgs.cifs-utils.bin
        pkgs.samba
      ];
    };
  };
}
