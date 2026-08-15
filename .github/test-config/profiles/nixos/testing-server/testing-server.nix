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

    mainUser = "testuser-server";

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
        power = {
          ups = {
            deviceMatch = {
              vendorid = "ffff";
              productid = "ffff";
            };
          };
        };
        todo = {
          todoist-api = {
            defaultProjectId = "ffffffffffffffff";
            defaultSectionId = "eeeeeeeeeeeeeeee";
            defaultAssignee = "testuser";
            knownAssignees = {
              testuser = "dddddddd";
            };
          };
        };
        notifications = {
          pushover = true;
        };
        services = {
          signal-bot = {
            configured = true;
            chatEnable = true;
            chatRecipients = {
              testldap = "testldap";
            };
            chatDefaultRecipient = "testldap";
            mainGroupName = "Test Home Assistant";
            haUrl = "https://homeassistant.testingserver.example:8123";
            enableAvatar = true;
            enableGroupAvatar = true;
            groupFilter = {
              enable = true;
              agentId = "testing_group_filter";
              instruction = "Answer with YES, MAYBE or NO and nothing else.";
            };
            transcription = {
              maxAttachmentBytes = 8388608;
              attachmentRetentionMinutes = 30;
            };
            additionalHookSendsPerDay = 3;
            minSecondsBetweenHooks = 900;
            minSecondsSinceBotMessage = 300;
            minSecondsSinceUserMessage = 300;
            hooksAgentId = "testing_hooks";
            hooksContextMaxChars = 8000;
            dailyTranscriptLimit = 150;
            hooks = {
              hook-a = {
                startTime = "07:00";
                endTime = "09:00";
                probability = 0.5;
                minUserInteractions = 2;
                whenTriggered = [
                  {
                    instruction = "Some instructions";
                    title = "Some title";
                  }
                ];
              };
              hook-b = {
                startTime = "22:00";
                endTime = "01:00";
                probability = 0.75;
                contextFirstMessages = 3;
                contextRecentMessages = 10;
                onBlock = "skip";
                agentId = "hook_agent";
                sendErrorsIntoChat = true;
                whenTriggered = [
                  {
                    instruction = "Some midnight spanning hook";
                    title = "Some other title";
                    url = "https://homeassistant.testingserver.example:8123/todo";
                  }
                  {
                    instruction = "Some single instruction";
                  }
                  {
                    message = "Some static message";
                  }
                ];
              };
            };
          };
          whisper = {
            model = "base";
            language = "de";
            backend = "server";
            server = {
              port = 8643;
            };
          };
        };
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
          auth = {
            enableOAuthProxy = true;
          };
          ollama = true;
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
                groups = [ "signal-chat-users" ];
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
        system = {
          auto-upgrades = {
            schedule = "17:45:10";
            rebootWindow = {
              lower = "22:30";
              upper = "05:00";
            };
          };
        };
        storage = {
          luks-data-drive = {
            uuid = "ffffffff-ffff-ffff-ffff-ffffffffffff";
            createXDGDirs = true;
          };
        };
      };
    };

    settings = { };

    impermanence = false;
  };
}
