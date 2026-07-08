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
  name = "pass";

  group = "proton";
  input = "common";

  unfree = [
    "proton-authenticator"
    "proton-pass-cli"
  ];

  settings = {
    forceX11 = true;
  };

  submodules = lib.optionalAttrs self.isLinux {
    linux = {
      software = {
        flatpak = true;
      };
    };
  };

  module = {
    home = config: {
      home.packages = with pkgs; [
        proton-authenticator
        proton-pass-cli
      ];
    };

    linux.home = config: {
      services.flatpak.packages = [ "me.proton.Pass" ];

      services.flatpak.overrides."me.proton.Pass".Environment = {
        ELECTRON_OZONE_PLATFORM_HINT = if self.settings.forceX11 then "x11" else "auto";
      };

      home.file."${defs.binDir}/proton-pass" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exec ${pkgs.flatpak}/bin/flatpak run me.proton.Pass "$@"
        '';
      };
    };

    darwin.home = config: {
      home.packages = [
        pkgs.proton-pass
      ];
    };
  };
}
