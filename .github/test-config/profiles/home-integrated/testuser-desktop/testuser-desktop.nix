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
  };
}
