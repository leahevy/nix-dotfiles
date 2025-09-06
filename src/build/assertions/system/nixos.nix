args@{
  lib,
  funcs,
  helpers,
  defs,
  host,
  ...
}:
{ config, ... }:

{
  assertions = [
    {
      assertion = builtins.match "^[0-9]+[MG]$" host.settings.system.tmpSize != null;
      message = "host.settings.system.tmpSize must be in format '{number}M' or '{number}G' (e.g., '4G', '512M')";
    }
    {
      assertion = builtins.isAttrs host.mainUser;
      message = "host.mainUser must be an attribute set (processed config) at assertion time";
    }
    {
      assertion = builtins.all builtins.isAttrs host.additionalUsers;
      message = "All host.additionalUsers must be attribute sets (processed configs) at assertion time";
    }
  ]
  ++ helpers.assertNotNull "host" host [
    "hostname"
    "mainUser"
  ];
}
