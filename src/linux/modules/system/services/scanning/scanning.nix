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
  name = "scanning";

  group = "services";
  input = "linux";
  namespace = "system";

  defaults = {
    addMainUserToGroup = true;
    disableEsclBackend = false;
    disablePixmaBackend = false;
    openFirewall = true;
    withAvahi = true;
    withHPDriver = false;
    withEpsonDriver = false;
    withUtsushiDriver = false;
  };

  configuration =
    context@{ config, options, ... }:
    let
      customPkgs = (
        self.pkgs {
          overlays = [
            (final: prev: {
              xsane = prev.xsane.override {
                gimpSupport = true;
              };
            })
          ];
        }
      );
    in
    {

      services.avahi = lib.mkIf self.settings.withAvahi {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
        openFirewall = true;
      };

      users.users = lib.mkIf self.settings.addMainUserToGroup {
        "${self.host.mainUser.username}" = {
          extraGroups = [ "scanner" ];
        };
      };

      services.udev.packages =
        (with pkgs; [
          sane-airscan
        ])
        ++ lib.optionals self.settings.withUtsushiDriver (
          with pkgs;
          [
            utsushi
          ]
        );

      hardware.sane = {
        enable = true;
        disabledDefaultBackends =
          [ ]
          ++ lib.optionals self.settings.disableEsclBackend [ "escl" ]
          ++ lib.optionals self.settings.disablePixmaBackend [ "pixma" ];
        openFirewall = self.settings.openFirewall;
        extraBackends =
          (with pkgs; [
            sane-airscan
          ])
          ++ lib.optionals self.settings.withHPDriver (
            with pkgs;
            [
              hplip
            ]
          )
          ++ lib.optionals self.settings.withEpsonDriver (
            with pkgs;
            [
              epkowa
            ]
          )
          ++ lib.optionals self.settings.withUtsushiDriver (
            with pkgs;
            [
              utsushi
            ]
          );
      };

      services.ipp-usb.enable = true;

      environment.systemPackages = [
        customPkgs.xsane
      ];

      environment.persistence.${self.persist} = {
        directories = [
          "/var/lib/ipp-usb"
        ];
      };
    };
}
