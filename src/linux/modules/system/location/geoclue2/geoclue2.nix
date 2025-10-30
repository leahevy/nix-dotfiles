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
  name = "geoclue2";

  group = "location";
  input = "linux";
  namespace = "system";

  settings = {
    enableWifi = false;
    baseWhitelistedAgents = [
      "org.qutebrowser.qutebrowser"
    ];
    additionalWhitelistedAgents = [ ];
    baseWhitelistedSystemAgents = [ ];
    additionalWhitelistedSystemAgents = [ ];
    staticAccuracy = 100;
  };

  configuration =
    context@{ config, options, ... }:
    let
      allWhitelistedAgents =
        self.settings.baseWhitelistedAgents ++ self.settings.additionalWhitelistedAgents;
      allWhitelistedSystemAgents =
        self.settings.baseWhitelistedSystemAgents ++ self.settings.additionalWhitelistedSystemAgents;
      userUid = toString config.users.users.${self.host.mainUser.username}.uid;

      generateUserAppConfig =
        agents:
        lib.listToAttrs (
          map (agent: {
            name = agent;
            value = {
              isAllowed = true;
              isSystem = false;
              users = [ userUid ];
            };
          }) agents
        );

      generateSystemAppConfig =
        agents:
        lib.listToAttrs (
          map (agent: {
            name = agent;
            value = {
              isAllowed = true;
              isSystem = true;
            };
          }) agents
        );

      userAppConfig = generateUserAppConfig allWhitelistedAgents;
      systemAppConfig = generateSystemAppConfig allWhitelistedSystemAgents;
      mergedAppConfig = userAppConfig // systemAppConfig;
    in
    {
      services.geoclue2 = {
        enable = true;
        enableWifi = self.settings.enableWifi;
        enableStatic = true;
        staticLatitude = self.host.location.latitude;
        staticLongitude = self.host.location.longitude;
        staticAltitude = self.host.location.altitude;
        staticAccuracy = self.settings.staticAccuracy;
        appConfig = mergedAppConfig;
      };
    };
}
