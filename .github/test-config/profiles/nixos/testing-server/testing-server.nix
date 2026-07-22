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
    hostname = "testing-server";

    mainUser = "testuser";

    deploymentMode = "develop";

    addBaseGroup = true;

    sopsPublicKey = "@SOPS_AGE_PUBLIC_KEY@";

    remote = {
      address = "testingserver.example";
      deploySSHPublicKey = "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA test-deploy";
      initrdSSHHostPrivateKey = "-----BEGIN OPENSSH PRIVATE KEY-----\ndummy-testing-key-not-a-real-secret\n-----END OPENSSH PRIVATE KEY-----\n";
      initrdSSHHostPublicKey = "ssh-ed25519 AAAABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB test-initrd";
      exposedServices = {
        auth = true;
        dashboard = true;
        paperless-ngx = "paperless";
        syncthing = true;
        searxng = true;
        proxy = true;
      };
    };

    modules = {
      linux = {
        security = {
          letsencrypt = {
            dnsCerts = {
              "testingserver.example" = {
                provider = "cloudflare";
              };
            };
          };
          "api-keys" = {
            keys = {
              "pocket-id" = {
                rotatedAt = {
                  year = 2026;
                  month = 7;
                  day = 22;
                };
              };
            };
          };
        };
        server = {
          auth = true;
          dashboard = true;
          healthchecks = {
            projectUUID = "12345678-1234-1234-1234-123456789abc";
            pingBaseUrl = "https://hc.testingserver.example/ping";
            healthchecksBaseUrl = "https://hc.testingserver.example";
          };
          ldap = {
            users = [
              {
                username = "testldap";
                email = "testldap@example.com";
              }
            ];
            groups = [ "testgroup" ];
          };
          nginx = {
            serverOwnsBaseDomain = true;
          };
          paperless-ngx = true;
          pocket-id = true;
          postgresql = true;
          samba = {
            shares = [
              {
                name = "testshare";
              }
            ];
          };
          searxng = true;
          syncthing = true;
          tika = true;
        };
      };
    };

    settings = { };

    impermanence = false;
  };
}
