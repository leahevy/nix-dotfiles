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
  name = "sysctl";

  group = "core";
  input = "build";
  namespace = "system";

  settings = {
    inotify = {
      maxUserWatches = 1048576;
      maxQueuedEvents = 262144;
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      boot.kernel.sysctl = {
        "fs.inotify.max_user_watches" = self.settings.inotify.maxUserWatches;
        "fs.inotify.max_queued_events" = self.settings.inotify.maxQueuedEvents;
      };
    };
}
