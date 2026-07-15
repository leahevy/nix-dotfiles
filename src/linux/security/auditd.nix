args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  baselineWatches = { };

  baselineDirWatches = {
    dir_root = "/root";
  };

  resolveWatchPath = path: if lib.hasPrefix "/" path then path else "${self.user.home}/${path}";
in
{
  name = "auditd";
  description = "Linux audit baseline for mutable system files";

  group = "security";
  input = "linux";

  options = {
    extraRules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Raw audit rule lines injected by other modules and appended after the host extra rules.";
    };
    fileWatches = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Audit file watches injected by other modules as an attrset mapping rule keys to paths.";
    };
    dirWatches = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Audit dir watches injected by other modules as an attrset mapping rule keys to paths.";
    };
  };

  module = {
    enabled =
      config:
      let
        hostWatches =
          if self ? host then
            lib.mapAttrs (key: path: resolveWatchPath path) self.host.settings.security.auditd.fileWatches
          else
            { };
        hostDirWatches =
          if self ? host then
            lib.mapAttrs (key: path: resolveWatchPath path) self.host.settings.security.auditd.dirWatches
          else
            { };
        hostExtraRules = if self ? host then self.host.settings.security.auditd.extraRules else [ ];
        injectedExtraRules = config.nx.linux.security.auditd.extraRules;
        injectedWatches = lib.mapAttrs (
          key: path: resolveWatchPath path
        ) config.nx.linux.security.auditd.fileWatches;
        injectedDirWatches = lib.mapAttrs (
          key: path: resolveWatchPath path
        ) config.nx.linux.security.auditd.dirWatches;
        parseWatchRule =
          rule:
          builtins.match "^-w[[:space:]]+([^[:space:]]+).*[[:space:]]-k[[:space:]]+([a-zA-Z0-9_-]+)[[:space:]]*$" rule;
        extraRuleWatches = lib.listToAttrs (
          lib.concatMap (
            rule:
            let
              m = parseWatchRule rule;
            in
            if m == null then [ ] else [ (lib.nameValuePair (lib.elemAt m 1) (lib.elemAt m 0)) ]
          ) (hostExtraRules ++ injectedExtraRules)
        );
        watchPathByKey = baselineWatches // hostWatches // injectedWatches // extraRuleWatches;
        watchTitle =
          key:
          if lib.hasPrefix "id_" key then
            "Identity File Changed"
          else if lib.hasPrefix "sshkey_" key then
            "SSH Host Key Changed"
          else
            "Watched File Changed";
        watchActive = key: if lib.hasPrefix "sshkey_" key then "always" else "outsideRebuild";
        watchPatterns = lib.mapAttrsToList (key: path: {
          service = "auditd.service";
          tag = "audisp-syslog";
          string = "type=SYSCALL .*key=\"${key}\"";
          active = watchActive key;
          extract = "AUID=\"(?P<user>[^\"]*)\"";
          mapping = {
            label = "Audit";
            title = watchTitle key;
            icon = "dialog-warning";
            priority = "warn";
            message = "{user} changed ${path}";
          };
        }) watchPathByKey;
        dirWatchPatterns = lib.mapAttrsToList (key: path: {
          service = "auditd.service";
          tag = "audisp-syslog";
          string = "type=SYSCALL .*key=\"${key}\"";
          active = "outsideRebuild";
          extract = "AUID=\"(?P<user>[^\"]*)\"";
          mapping = {
            label = "Audit";
            title = "Directory Attributes Changed";
            icon = "dialog-warning";
            priority = "warn";
            message = "{user} changed attributes of ${path}";
          };
        }) (baselineDirWatches // hostDirWatches // injectedDirWatches);
      in
      {
        nx.linux.monitoring.journal-watcher.highlightPatterns =
          watchPatterns
          ++ dirWatchPatterns
          ++ [
            {
              service = "nx-audit-rules-pending.service";
              string = "Audit rules changed and will be applied on reboot";
              mapping = {
                label = "Audit";
                title = "Audit Rules Pending";
                icon = "dialog-warning";
                priority = "warn";
              };
            }
            {
              service = "auditd.service";
              tag = "audisp-syslog";
              string = "type=KERN_MODULE .*name=\"[^\"]+\"";
              extract = "name=\"(?P<name>[^\"]+)\"";
              mapping = {
                label = "Audit";
                title = "Kernel Module Event";
                icon = "dialog-warning";
                priority = "warn";
                message = "Kernel module {name} loaded or removed";
              };
            }
            {
              service = "auditd.service";
              tag = "audisp-syslog";
              string = "type=SYSCALL .*key=\"(?!id_|sshkey_|modules\"|access_denied\")[a-zA-Z0-9_-]+\"";
              active = "outsideRebuild";
              extract = "key=\"(?P<key>[a-zA-Z0-9_-]+)\".*AUID=\"(?P<user>[^\"]*)\"";
              mapping = {
                label = "Audit";
                title = "Watched File Changed";
                icon = "dialog-warning";
                priority = "warn";
                message = "{user} changed {key}";
              };
            }
          ];

        nx.linux.monitoring.journal-watcher.ignorePatterns = [
          {
            string = "kauditd_printk_skb: [0-9]+ callbacks suppressed";
            kernel = true;
          }
        ];
      };

    linux.system =
      {
        config,
        extraRules,
        fileWatches,
        dirWatches,
        ...
      }:
      let
        auditdHost = self.host.settings.security.auditd;

        reservedKeys =
          lib.attrNames baselineWatches
          ++ lib.attrNames baselineDirWatches
          ++ [
            "modules"
            "access_denied"
          ];

        renderWatch = key: path: "-w ${path} -p wa -k ${key}";

        auidUnset = "4294967295";

        dirWatchSyscalls =
          if self.isAARCH64 then
            "fchmod,fchmodat,fchown,fchownat"
          else
            "chmod,fchmod,fchmodat,chown,fchown,lchown,fchownat";
        renderDirWatch =
          key: path:
          "-a always,exit -F arch=b64 -S ${dirWatchSyscalls} -F path=${path} -F filetype=dir -F auid!=${auidUnset} -k ${key}";

        baselineRules =
          lib.mapAttrsToList renderWatch baselineWatches
          ++ lib.mapAttrsToList renderDirWatch baselineDirWatches
          ++ [
            "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -F auid!=${auidUnset} -k modules"
          ];
        fileWatchRules = lib.mapAttrsToList (
          key: path: renderWatch key (resolveWatchPath path)
        ) auditdHost.fileWatches;
        dirWatchRules = lib.mapAttrsToList (
          key: path: renderDirWatch key (resolveWatchPath path)
        ) auditdHost.dirWatches;
        injectedWatchRules = lib.mapAttrsToList (
          key: path: renderWatch key (resolveWatchPath path)
        ) fileWatches;
        injectedDirWatchRules = lib.mapAttrsToList (
          key: path: renderDirWatch key (resolveWatchPath path)
        ) dirWatches;

        openSyscalls = if self.isAARCH64 then "openat" else "open,openat";
        accessDeniedRulesList = lib.optionals auditdHost.accessDeniedRules [
          "-a always,exit -F arch=b64 -S ${openSyscalls} -F exit=-EACCES -F auid>=1000 -F auid!=${auidUnset} -k access_denied"
          "-a always,exit -F arch=b64 -S ${openSyscalls} -F exit=-EPERM -F auid>=1000 -F auid!=${auidUnset} -k access_denied"
        ];

        keyValid = key: builtins.match "[a-zA-Z0-9_-]+" key != null && builtins.stringLength key <= 31;

        excludeRules = map (t: "-a always,exclude -F msgtype=${t}") auditdHost.excludeMessageTypes;

        finalAuditRules = [
          "-c"
        ]
        ++ excludeRules
        ++ baselineRules
        ++ fileWatchRules
        ++ dirWatchRules
        ++ injectedWatchRules
        ++ injectedDirWatchRules
        ++ accessDeniedRulesList
        ++ auditdHost.extraRules
        ++ extraRules;

        rulesHash = builtins.hashString "sha256" (lib.concatStringsSep "\n" finalAuditRules);
      in
      {
        assertions =
          lib.mapAttrsToList (key: path: {
            assertion = keyValid key;
            message = "auditd fileWatches key '${key}' must match [a-zA-Z0-9_-]+ and be at most 31 characters long!";
          }) auditdHost.fileWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = !(lib.elem key reservedKeys);
            message = "auditd fileWatches key '${key}' collides with a reserved baseline key!";
          }) auditdHost.fileWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = path != "";
            message = "auditd fileWatches path for key '${key}' must not be empty!";
          }) auditdHost.fileWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = keyValid key;
            message = "auditd dirWatches key '${key}' must match [a-zA-Z0-9_-]+ and be at most 31 characters long!";
          }) auditdHost.dirWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = !(lib.elem key reservedKeys);
            message = "auditd dirWatches key '${key}' collides with a reserved baseline key!";
          }) auditdHost.dirWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = !(lib.hasAttr key auditdHost.fileWatches);
            message = "auditd dirWatches key '${key}' is also defined in fileWatches!";
          }) auditdHost.dirWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = path != "";
            message = "auditd dirWatches path for key '${key}' must not be empty!";
          }) auditdHost.dirWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = keyValid key;
            message = "auditd injected fileWatches key '${key}' must match [a-zA-Z0-9_-]+ and be at most 31 characters long!";
          }) fileWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion =
              !(lib.elem key (
                reservedKeys ++ lib.attrNames auditdHost.fileWatches ++ lib.attrNames auditdHost.dirWatches
              ));
            message = "auditd injected fileWatches key '${key}' collides with a reserved or host-defined key!";
          }) fileWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = path != "";
            message = "auditd injected fileWatches path for key '${key}' must not be empty!";
          }) fileWatches;

        security.audit = {
          enable = if auditdHost.locked then "lock" else true;
          backlogLimit = auditdHost.backlogLimit;
          rules = finalAuditRules;
        };

        systemd.services.nx-audit-rules-pending = lib.mkIf auditdHost.locked {
          description = "Audit Rules Pending Reboot Check";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            marker=/run/nx-audit-rules-booted
            if [ ! -e "$marker" ]; then
              ${pkgs.coreutils}/bin/printf '%s' "${rulesHash}" > "$marker"
            elif [ "$(${pkgs.coreutils}/bin/cat "$marker")" != "${rulesHash}" ]; then
              ${pkgs.coreutils}/bin/echo "Audit rules changed and will be applied on reboot"
            fi
          '';
        };

        systemd.services.audit-rules-nixos = lib.mkIf auditdHost.locked {
          restartIfChanged = false;
          serviceConfig.ExecStopPost = lib.mkForce [ ];
        };

        security.auditd = {
          enable = true;
          settings = {
            max_log_file = auditdHost.maxLogFileMB;
            num_logs = auditdHost.numLogs;
            max_log_file_action = "rotate";
            space_left = "10%";
            space_left_action = "syslog";
            admin_space_left = "5%";
            q_depth = auditdHost.queueDepth;
          };
          plugins.syslog.active = true;
        };

        environment.persistence."${self.persist}" = {
          directories = [ "/var/log/audit" ];
        };
      };
  };
}
