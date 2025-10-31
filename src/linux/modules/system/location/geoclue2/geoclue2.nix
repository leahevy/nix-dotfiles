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
    enableCellular = false;
    enableNMEA = false;
    withDemoAgent = true;
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

      onlyStaticEnabled =
        !(self.settings.enableWifi || self.settings.enableCellular || self.settings.enableNMEA);
    in
    {
      services.geoclue2 = {
        enable = true;
        enableWifi = self.settings.enableWifi;
        enable3G = self.settings.enableCellular;
        enableCDMA = self.settings.enableCellular;
        enableModemGPS = self.settings.enableCellular;
        enableNmea = self.settings.enableNMEA;
        enableDemoAgent = self.settings.withDemoAgent;
        enableStatic = onlyStaticEnabled;
        staticLatitude = self.host.location.latitude;
        staticLongitude = self.host.location.longitude;
        staticAltitude = self.host.location.altitude;
        staticAccuracy = self.settings.staticAccuracy;
        appConfig = mergedAppConfig;
      };
    };
}
