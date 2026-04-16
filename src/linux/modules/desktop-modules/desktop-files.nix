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

  options = {
    entries = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            exec = lib.mkOption {
              type = lib.types.str;
              description = "Command to execute";
            };
            name = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Display name (defaults to capitalized entry key)";
            };
            genericName = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            comment = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Icon name (defaults to entry key)";
            };
            terminal = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            type = lib.mkOption {
              type = lib.types.str;
              default = "Application";
            };
            categories = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "Other" ];
            };
            mimeType = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            startupNotify = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
            noDisplay = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            settings = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
            };
          };
        }
      );
      default = { };
      description = "Desktop file entries";
    };
  };

  module = {
    enabled = config: {
      nx.lib.primaryIcons = lib.filter (icon: icon != null && icon != "") (
        lib.mapAttrsToList (
          name: entry: if entry.icon != null && entry.icon != "" then entry.icon else name
        ) (self.options config).entries
      );
    };

    home =
      { config, entries, ... }:
      let
        scriptEntries = lib.mapAttrs (
          name: entry:
          let
            expandedExec = lib.replaceStrings [ "~/" ] [ "${config.home.homeDirectory}/" ] entry.exec;
          in
          {
            executable = true;
            text = ''
              #!/bin/sh
              set -e
              ${expandedExec}
            '';
          }
        ) entries;
      in
      {
        home.file = lib.mapAttrs' (
          name: script: lib.nameValuePair ".local/bin/scripts/desktop-files/${name}.sh" script
        ) scriptEntries;

        xdg.desktopEntries = lib.mapAttrs (
          name: entry:
          let
            defaultName = lib.toUpper (lib.substring 0 1 name) + lib.substring 1 (-1) name;
          in
          {
            name = if entry.name != null then entry.name else defaultName;
            genericName = entry.genericName;
            comment = entry.comment;
            exec = "${config.home.homeDirectory}/.local/bin/scripts/desktop-files/${name}.sh";
            icon = if entry.icon != null then entry.icon else name;
            terminal = entry.terminal;
            type = entry.type;
            categories = entry.categories;
            mimeType = entry.mimeType;
            startupNotify = entry.startupNotify;
            noDisplay = entry.noDisplay;
            settings = entry.settings;
          }
        ) entries;
      };
  };
}
