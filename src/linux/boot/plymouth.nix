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
  name = "plymouth";

  group = "boot";
  input = "linux";

  disableOnVirtual = true;

  module = {
    linux.system =
      config:
      let
        themeScript = import (self.inputs.stylix + "/modules/plymouth/theme-script.nix") {
          inherit lib;
          cfg.logoAnimated = true;
          colors = {
            base00-dec-r = "0";
            base00-dec-g = "0";
            base00-dec-b = "0";
            base05-dec-r = "0.5490";
            base05-dec-g = "0.6510";
            base05-dec-b = "0.5490";
          };
        };

        theme = pkgs.runCommand "nxboot-plymouth" { } ''
          themeDir="$out/share/plymouth/themes/nxboot"
          mkdir -p $themeDir

          ${lib.getExe' pkgs.imagemagick "convert"} \
            -background transparent \
            -bordercolor transparent \
            -border 42% \
            ${
              helpers.packageFile args pkgs.nixos-icons "share/icons/hicolor/256x256/apps/nix-snowflake.png"
            } \
            $themeDir/logo.png

          cp ${themeScript} $themeDir/nxboot.script

          cat > $themeDir/nxboot.plymouth << EOF
          [Plymouth Theme]
          Name=NXBoot
          ModuleName=script

          [script]
          ImageDir=$themeDir
          ScriptFile=$themeDir/nxboot.script
          EOF
        '';
      in
      {
        stylix.targets.plymouth.enable = lib.mkForce false;

        boot = {
          initrd = {
            systemd.enable = lib.mkForce true;
            verbose = false;
          };

          consoleLogLevel = 3;

          kernelParams = [
            "splash"
            "quiet"
            "loglevel=3"
            "boot.shell_on_fail"
            "udev.log_priority=3"
            "intremap=on"
            "rd.systemd.show_status=auto"
          ];

          plymouth = {
            enable = true;
            font = "${helpers.packageFile args pkgs.hack-font "share/fonts/truetype/Hack-Regular.ttf"}";
            logo = "${helpers.packageFile args pkgs.nixos-icons
              "share/icons/hicolor/128x128/apps/nix-snowflake.png"
            }";
            theme = "nxboot";
            themePackages = [ theme ];
          };
        };
      };
  };
}
