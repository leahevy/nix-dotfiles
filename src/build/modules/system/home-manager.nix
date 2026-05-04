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
  name = "home-manager";

  group = "system";
  input = "build";

  module = {
    linux.system =
      config:
      let
        extension =
          let
            ext = self.variables.home-manager-backup-extension or null;
          in
          if lib.isString ext && ext != "" then
            ext
          else
            throw "variables.home-manager-backup-extension must be a non-empty string!";
        username = self.host.mainUser.username;

        homeFilePaths = lib.attrNames (config.home-manager.users.${username}.home.file or { });

        backupFiles = map (f: "${self.user.home}/${f}.${extension}") homeFilePaths;

        removeBackupsScript = pkgs.writeShellScript "remove-backups-script" ''
          COUNT=0
          ${lib.concatMapStringsSep "\n" (f: ''
            if [ -e ${lib.escapeShellArg f} ] || [ -L ${lib.escapeShellArg f} ]; then
              ${pkgs.coreutils}/bin/echo "Remove backup ${f}"
              ${pkgs.coreutils}/bin/rm ${lib.escapeShellArg f} || true
              COUNT=$((COUNT + 1))
            fi
          '') backupFiles}
          ${pkgs.coreutils}/bin/echo "Removed $COUNT backup files"
        '';
      in
      lib.mkIf (backupFiles != [ ]) {
        systemd.services."home-manager-${username}".wants = [ "home-manager-remove-backups.service" ];

        systemd.services.home-manager-remove-backups = {
          unitConfig = {
            Description = "Remove .${extension} files for all home.file generated files";
            PartOf = [ "home-manager-${username}.service" ];
            Before = [
              "systemd-user-sessions.service"
              "home-manager-${username}.service"
            ];
            RequiresMountsFor = "${self.user.home}";
          };
          serviceConfig = {
            Type = "oneshot";
            User = username;
            ExecStart = "${removeBackupsScript}";
          };
        };
      };
  };
}
