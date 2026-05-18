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
let
  execFieldCodePattern = "%%|%f|%F|%u|%U|%i|%c|%k|%d|%D|%n|%N|%v|%m";

  splitExecFieldCodes =
    exec:
    let
      match = builtins.match "([^%]*)(${execFieldCodePattern})(.*)" exec;
    in
    if match == null then
      {
        command = exec;
        placeholders = [ ];
      }
    else
      let
        prefix = builtins.elemAt match 0;
        code = builtins.elemAt match 1;
        rest = builtins.elemAt match 2;
        next = splitExecFieldCodes rest;
      in
      {
        command = prefix + (if code == "%%" then "%" else "") + next.command;
        placeholders = (if code == "%%" then [ ] else [ code ]) ++ next.placeholders;
      };

  hasSingleContiguousPlaceholderBlock =
    exec:
    let
      go =
        state: remaining:
        let
          match = builtins.match "([^%]*)(${execFieldCodePattern})(.*)" remaining;
        in
        if match == null then
          true
        else
          let
            prefix = builtins.elemAt match 0;
            code = builtins.elemAt match 1;
            rest = builtins.elemAt match 2;
          in
          if code == "%%" then
            go state rest
          else if state == "before" then
            go "inside" rest
          else if state == "inside" then
            if prefix == "" then go "inside" rest else go "after" rest
          else
            false;
    in
    go "before" exec;
in
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
            validateIcon = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to validate the icon name against the system's icon theme";
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
    enabled =
      config:
      let
        entries = (self.options config).entries;
      in
      {
        assertions = lib.mapAttrsToList (name: entry: {
          assertion = hasSingleContiguousPlaceholderBlock entry.exec;
          message = "desktop-files entry '${name}' exec must keep desktop field codes in one contiguous block when using the wrapper script approach!";
        }) entries;

        nx.lib.primaryIcons = lib.filter (icon: icon != null && icon != "") (
          lib.mapAttrsToList (
            name: entry: if entry.icon != null && entry.icon != "" then entry.icon else name
          ) (lib.filterAttrs (_: entry: entry.validateIcon) entries)
        );
      };

    home =
      { config, entries, ... }:
      let
        scriptEntries = lib.mapAttrs (
          name: entry:
          let
            expandedExec = lib.replaceStrings [ "~/" ] [ "${config.home.homeDirectory}/" ] entry.exec;
            parsedExec = splitExecFieldCodes expandedExec;
          in
          pkgs.writeShellScript "desktop-files-${name}" ''
            set -e
            ${parsedExec.command} "$@"
          ''
        ) entries;
      in
      {
        xdg.desktopEntries = lib.mapAttrs (
          name: entry:
          let
            defaultName = lib.toUpper (lib.substring 0 1 name) + lib.substring 1 (-1) name;
            parsedExec = splitExecFieldCodes entry.exec;
            placeholderSuffix =
              if parsedExec.placeholders == [ ] then
                ""
              else
                " " + lib.concatStringsSep " " parsedExec.placeholders;
          in
          {
            name = if entry.name != null then entry.name else defaultName;
            genericName = entry.genericName;
            comment = entry.comment;
            exec = "${scriptEntries.${name}}${placeholderSuffix}";
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
