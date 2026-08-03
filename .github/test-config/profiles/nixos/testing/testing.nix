{
  lib,
  pkgs,
  variables,
  helpers,
  defs,
  self,
  ...
}:
{
  config.host = {
    hostname = "testing";

    mainUser = "testuser-desktop";

    deploymentMode = "develop";

    addBaseGroup = true;

    isVMHost = true;
    crossBuild = true;

    sopsPublicKey = "@SOPS_AGE_PUBLIC_KEY@";

    modules = {
      linux = {
        desktop-modules = {
          keyd = {
            enableDevices = {
              kensingtonExpertMouse = true;
            };
          };
        };
        sound = {
          pipewire = {
            defaultSink = "headset";
            defaultSourceID = "some-source";
            speakerSinkID = "some-sink";
            headsetSinkID = "some-other-sink";
          };
        };
        location = {
          geoclue2 = true;
        };
        mail = {
          sendmail = {
            to = "test@example.com";
            from = "test@example.com";
            host = "smtp.example.com";
          };
        };
        networking = {
          tailscale = true;
        };
        virtualisation = {
          podman = true;
        };
        notifications = {
          pushover = {
            enableE2EEncryption = true;
            enableSendmail = false;
          };
        };
        security = {
          aide = true;
          bitwarden-secret = true;
          letsencrypt = {
            dnsCerts = {
              "example.com" = {
                provider = "cloudflare";
              };
            };
          };
          yubikey = {
            lockSessionOnUnplug = true;
            enableU2fAuth = true;
          };
        };
        games = {
          controller = true;
          steam = {
            dataPath = "/data/steam";
          };
        };
        power = {
          modes = {
            sleep = false;
            suspend = false;
            hibernate = false;
            hybridSleep = false;
          };
        };
        bluetooth = {
          bluetooth = true;
        };
        services = {
          printing = {
            configureDefaultPrinter = true;
            defaultPrinterName = "Printer";
            defaultPrinterIP = "192.168.1.1";
          };
          scanning = {
            disableEsclBackend = true;
            disablePixmaBackend = true;
          };
        };
        monitoring = {
          journal-watcher = {
            ignorePatterns = [
              {
                kernel = true;
                string = "some-extra-kernel-pattern";
              }
            ];
          };
        };
        storage = {
          samba-utils = true;
          usb-access = true;
          borg-backup = {
            repository = {
              server = "example.com";
              port = 22;
              user = "example";
              path = "/backups";
            };
            schedule = "*-*-* 18:45:00";
            repoCheckMaxDuration = 900;
          };
        };
        system = {
          nix-ld = true;
        };
      };
    };

    displays = {
      main = "HDMI-1";
      mainIsWidescreen = true;
    };

    location = {
      latitude = 5.0;
      longitude = 10.0;
      altitude = 1234.0;
    };

    settings = {
      system = {
        vmsDataPath = "/data/vms";
        virtualisation = {
          enableKVM = true;
        };
        tmpSize = "4G";
        desktop = "gnome";
        firmware = {
          modeSwitchDevices = [
            { device = "1234:5678"; }
          ];
        };
      };
    };

    impermanence = false;

    homeserverDomain = "example.com";
  };
}
