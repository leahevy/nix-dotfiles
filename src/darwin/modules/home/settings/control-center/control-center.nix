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
  name = "control-center";

  group = "settings";
  input = "darwin";
  namespace = "home";

  submodules = {
    darwin = {
      settings = {
        main = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              controlCenter = {
                accessibilityShortcuts = {
                  showInMenuBar = false;
                  showInControlCenter = true;
                };
                airdrop = true;
                battery = {
                  showInMenuBar = true;
                  showInControlCenter = true;
                };
                batteryShowPercentage = true;
                bluetooth = true;
                display = "always";
                fastUserSwitching = {
                  showInMenuBar = false;
                  showInControlCenter = true;
                };
                focusModes = "always";
                hearing = {
                  showInMenuBar = false;
                  showInControlCenter = true;
                };
                keyboardBrightness = {
                  showInMenuBar = false;
                  showInControlCenter = true;
                };
                musicRecognition = {
                  showInMenuBar = false;
                  showInControlCenter = true;
                };
                nowPlaying = "always";
                screenMirroring = "never";
                sound = "always";
                stageManager = (self.getModuleConfig "settings.stage-manager").enabled or false;
                wifi = true;
              };
            };
          };
        };
      };
    };
}
