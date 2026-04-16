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
  name = "wlsunset";

  group = "desktop-modules";
  input = "linux";

  settings = {
    location = if self.user.isStandalone then self.user.location else self.host.location;
  };

  assertions = [
    {
      assertion = self.settings.location.latitude != null;
      message = "Latitude required in user (on standalone) or host settings!";
    }
    {
      assertion = self.settings.location.longitude != null;
      message = "Longitude required in user (on standalone) or host settings!";
    }
  ];

  module = {
    linux.home = config: {
      services.wlsunset = {
        enable = true;
        latitude = self.settings.location.latitude;
        longitude = self.settings.location.longitude;
      };
    };
  };
}
