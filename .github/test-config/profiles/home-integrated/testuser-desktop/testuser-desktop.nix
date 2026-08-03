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
  config.user = {
    username = "testuser";

    fullname = "Test User";

    email = "testuser@example.com";

    addBaseGroup = true;

    modules = {
      common = {
        proton = {
          mail = {
            makeCalendarDefault = false;
          };
        };
        dev = {
          codex = {
            trustedProjects = [
              "/home/testuser/some-repo"
            ];
          };
        };
        services = {
          ollama = true;
          syncthing = {
            devices = [
              {
                name = "test";
                id = "AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA";
                ipAddress = "sync.example.com";
                protocol = "tcp";
                port = 22000;
                untrusted = true;
                shares = {
                  documents = "documents";
                };
              }
            ];
            trayEnabled = false;
          };
        };
        shell = {
          fish = {
            additionalFishFunctions = {
              some-function = ''
                echo test
              '';
            };
          };
        };
        drive = {
          cryptomator = {
            vaults = {
              secret = {
                vaultPath = "/data/secretdir";
                mountPath = "secret";
              };
            };
          };
        };
        nvim = {
          nixvim = {
            withData = true;
          };
          mcp-server = true;
        };
        nvim-modules = {
          obsidian = {
            wikiPath = "~/obsidian";
          };
          auto-save = {
            withData = true;
          };
        };
        browser = {
          firefox = {
            nextdnsID = "ffffff";
            userContentExcludedDomains = [
              "example.com"
            ];
          };
          browser = {
            home = "https://example.com";
            addAmazon = true;
            amazonDomain = "amazon.de";
            googleDomain = "google.de";
            bookmarks = {
              "test-folder" = {
                "test-bookmark" = "https://example.com";
              };
            };
          };
          qutebrowser-config = true;
        };
        chat = {
          discord = true;
        };
        video-conferencing = {
          zoom = true;
          teams = true;
        };
      };
      linux = {
        games = {
          steam = {
            withWayland = true;
          };
          heroic = {
            withWayland = true;
          };
        };
        security = {
          ausweisapp = true;
        };
        browser = {
          tor = true;
        };
        chat = {
          beeper = {
            waylandQuirks = true;
          };
        };
        desktop-modules = {
          web-app-chromium = true;
          rice-utils = true;
          keyring-unlock = true;
          desktop-files = {
            entries = { };
          };
        };
        storage = {
          borg-backup = {
            crossHostBorgHosts = {
              testing-server = {
                server = "test.example.com";
                port = 22;
                user = "borg-user";
                path = "/home/borg";
              };
            };
          };
        };
        graphics = {
          opengl = true;
          nvidia-setup = true;
        };
        web-apps = {
          google-calendar = true;
          google-mail = {
            makeDefault = false;
          };
          home-assistant = {
            subdomain = "home";
          };
        };
      };
    };

    settings = {
      hasRemoteCommand = true;
      terminal = "ghostty";
      sshd = {
        authorizedKeys = [
          "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA test@example.com"
        ];
      };
    };

    profile = {
      home =
        args@{
          lib,
          pkgs,
          funcs,
          helpers,
          defs,
          self,
          ...
        }:
        config: {
          home.file."testdir".source = lib.mkForce (helpers.symlinkToHomeDirPath config "data/testdir");
        };
    };
  };
}
