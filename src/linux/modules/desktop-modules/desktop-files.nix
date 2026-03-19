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
  name = "desktop-files";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  settings = {
    entries = { };
  };

  configuration =
    context@{ config, options, ... }:
    let
      scriptEntries = lib.mapAttrs (
        name: entry:
        let
          entryConfig = if builtins.isString entry then { exec = entry; } else entry;
          expandedExec = lib.replaceStrings [ "~/" ] [ "${config.home.homeDirectory}/" ] entryConfig.exec;
          scriptContent = ''
            #!/bin/sh
            set -e
            ${expandedExec}
          '';
        in
        {
          executable = true;
          text = scriptContent;
        }
      ) self.settings.entries;
    in
    {
      home.file = lib.mapAttrs' (
        name: script: lib.nameValuePair ".local/bin/scripts/desktop-files/${name}.sh" script
      ) scriptEntries;

      xdg.desktopEntries = lib.mapAttrs (
        name: entry:
        let
          entryConfig = if builtins.isString entry then { exec = entry; } else entry;
          defaultName = lib.toUpper (lib.substring 0 1 name) + lib.substring 1 (-1) name;
          scriptPath = "${config.home.homeDirectory}/.local/bin/scripts/desktop-files/${name}.sh";
        in
        {
          name = entryConfig.name or defaultName;
          genericName = entryConfig.genericName or null;
          comment = entryConfig.comment or null;
          exec = scriptPath;
          icon = entryConfig.icon or name;
          terminal = entryConfig.terminal or false;
          type = entryConfig.type or "Application";
          categories = entryConfig.categories or [ "Other" ];
          mimeType = entryConfig.mimeType or [ ];
          startupNotify = entryConfig.startupNotify or true;
          noDisplay = entryConfig.noDisplay or false;
          settings = entryConfig.settings or { };
        }
      ) self.settings.entries;
    };
}
