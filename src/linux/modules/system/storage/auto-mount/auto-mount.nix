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
  name = "auto-mount";

  group = "storage";
  input = "linux";
  namespace = "system";

  defaults = {
    hideInternalDevices = [
      "sda"
    ];
    hideDeviceMappers = [
      "cryptdata"
      "crypted"
    ];
    hideByLabel = [
      "data"
    ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      services.udisks2 = {
        enable = true;
        settings = {
          "udisks2.conf" = {
            defaults = {
              encryption = "luks2";
            };
            udisks2 = {
              modules = [ "*" ];
            };
          };
        };
      };

      security.polkit.enable = true;

      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
                action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
                action.id == "org.freedesktop.udisks2.filesystem-mount" ||
                action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
                action.id == "org.freedesktop.udisks2.encrypted-lock" ||
                action.id == "org.freedesktop.udisks2.eject-media") {

                if (subject.isInGroup("wheel")) {
                    var isRemovable = (action.lookup("drive.removable") === "true");
                    if (isRemovable) {
                        return polkit.Result.YES;
                    } else {
                        return polkit.Result.NO;
                    }
                }
            }
            return polkit.Result.NOT_HANDLED;
        });
      '';

      environment.systemPackages = with pkgs; [
        udisks2
        udiskie
      ];

      services.udev.packages = with pkgs; [
        udisks2
      ];

      services.udev.extraRules =
        let
          generateDeviceRules =
            devices:
            lib.concatMapStrings (device: ''
              SUBSYSTEM=="block", KERNEL=="${device}*", ENV{UDISKS_IGNORE}="1"
            '') devices;

          generateMapperRules =
            mappers:
            lib.concatMapStrings (mapper: ''
              SUBSYSTEM=="block", KERNEL=="dm-*", ENV{DM_NAME}=="${mapper}", ENV{UDISKS_IGNORE}="1"
            '') mappers;

          generateLabelRules =
            labels:
            lib.concatMapStrings (label: ''
              SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="${label}", ENV{UDISKS_IGNORE}="1"
            '') labels;
        in
        ''
          ${generateDeviceRules self.settings.hideInternalDevices}
          ${generateMapperRules self.settings.hideDeviceMappers}
          ${generateLabelRules self.settings.hideByLabel}

          SUBSYSTEM=="block", ATTR{removable}=="0", ATTRS{removable}=="0", ENV{UDISKS_IGNORE}="1"
        '';

      environment.persistence."${self.persist}" = {
        directories = [
          "/var/lib/udisks2"
        ];
      };
    };
}
