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
  name = "printing";

  defaults = {
    configureDefaultPrinter = false;
    additionalEnsurePrinters = [ ];
    addMainUserToGroup = true;
    withAvahi = true;
    withEpsonDriver = false;
    withHPDriver = false;
    withLexmarkDriver = false;
    withSamsungDriver = false;
    withBrotherDriver = false;
  };

  assertions = [
    {
      assertion =
        self.settings.configureDefaultPrinter
        && self.settings.defaultPrinterName != null
        && self.settings.defaultPrinterName != "";
      message = "Default printer is not set!";
    }
    {
      assertion =
        self.settings.configureDefaultPrinter
        && self.settings.defaultPrinterIP != null
        && self.settings.defaultPrinterIP != "";
      message = "Default printer is not set!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      services.avahi = lib.mkIf self.settings.withAvahi {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
        openFirewall = true;
      };

      services.printing = {
        enable = true;
        drivers =
          (with pkgs; [
            cups-filters
            cups-browsed
            gutenprint
            gutenprintBin
          ])
          ++ lib.optionals self.settings.withEpsonDriver (
            with pkgs;
            [
              epson-escpr
              epson-escpr2
            ]
          )
          ++ lib.optionals self.settings.withHPDriver (
            with pkgs;
            [
              hplip
            ]
          )
          ++ lib.optionals self.settings.withLexmarkDriver (
            with pkgs;
            [
              postscript-lexmark
            ]
          )
          ++ lib.optionals self.settings.withSamsungDriver (
            with pkgs;
            [
              splix
            ]
          )
          ++ lib.optionals self.settings.withBrotherDriver (
            with pkgs;
            [
              brlaser
            ]
          );
      };

      hardware.printers = {
        ensureDefaultPrinter = lib.mkIf self.settings.configureDefaultPrinter self.settings.defaultPrinterName;
        ensurePrinters =
          (
            if self.settings.configureDefaultPrinter then
              [
                {
                  deviceUri = "ipp://${self.settings.defaultPrinterIP}/ipp";
                  location = "home";
                  name = self.settings.defaultPrinterName;
                  model = "everywhere";
                }
              ]
            else
              [ ]
          )
          ++ self.settings.additionalEnsurePrinters;
      };

      systemd.services.ensure-printers =
        lib.mkIf (self.settings.configureDefaultPrinter || self.settings.additionalEnsurePrinters != [ ])
          {
            after = [
              "cups.service"
              "network-online.target"
            ];
            wants = [
              "cups.service"
              "network-online.target"
            ];
            wantedBy = lib.mkForce [ ];
            serviceConfig = {
              SuccessExitStatus = "0 1";
              Type = "oneshot";
              RemainAfterExit = true;
            };
          };

      systemd.timers.ensure-printers-delayed =
        lib.mkIf (self.settings.configureDefaultPrinter || self.settings.additionalEnsurePrinters != [ ])
          {
            wantedBy = [ "timers.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            timerConfig = {
              OnBootSec = "45s";
              Unit = "ensure-printers.service";
            };
          };

      users.users = lib.mkIf self.settings.addMainUserToGroup {
        "${self.host.mainUser.username}" = {
          extraGroups = [ "lp" ];
        };
      };

      environment.systemPackages =
        lib.mkIf (self.settings.configureDefaultPrinter || self.settings.additionalEnsurePrinters != [ ])
          [
            (pkgs.writeShellScriptBin "printers-detect" ''
              echo "Restarting ensure-printers service..."
              systemctl restart ensure-printers.service
              sleep 1
              echo
              echo "Service status:"
              systemctl status ensure-printers.service --no-pager -l
            '')
          ];

      environment.persistence.${self.persist} = {
        directories = [
          "/var/lib/cups"
          "/var/cache/cups"
        ];
      };
    };
}
