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
  name = "sound";

  group = "settings";
  input = "darwin";

  submodules = {
    darwin = {
      settings = {
        main = true;
      };
    };
  };

  settings = {
    sound = "Boop";
    volume = 0.5;
    enableSoundEffects = true;
  };

  module = {
    darwin.home = config: {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              sound = {
                soundEffects = {
                  alertSound = self.settings.sound;
                  alertVolume = self.settings.volume;
                  playFeedbackWhenVolumeIsChanged = true;
                  playUserInterfaceSoundEffects = self.settings.enableSoundEffects;
                };
              };
            };
          };
        };
      };
    };
  };
}
