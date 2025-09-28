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
  name = "keyd";

  assertions = [
    {
      assertion =
        (self.user.isStandalone or false)
        || (self.host.isModuleEnabled or (x: false)) "desktop-modules.keyd";
      message = "Requires linux.desktop-modules.keyd nixos module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        keyd
      ];

      home.file.".XCompose".source = "${pkgs.keyd}/share/keyd/keyd.compose";

      home.sessionVariables = {
        GTK_IM_MODULE = "xim";
        QT_IM_MODULE = "xim";
        XMODIFIERS = "@im=none";
      };
    };
}
