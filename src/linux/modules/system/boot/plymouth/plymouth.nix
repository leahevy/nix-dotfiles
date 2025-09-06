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
  configuration =
    context@{ config, options, ... }:
    {
      boot = {
        initrd = {
          systemd.enable = lib.mkForce true;
          verbose = false;
        };

        consoleLogLevel = 3;

        kernelParams = [
          "splash"
          "quiet"
          "boot.shell_on_fail"
          "udev.log_priority=3"
          "intremap=on"
          "rd.systemd.show_status=auto"
        ];

        plymouth = {
          enable = true;
          font = "${pkgs.hack-font}/share/fonts/truetype/Hack-Regular.ttf";
          logo = "${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake.png";
        };
      };
    };
}
