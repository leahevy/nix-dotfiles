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
  baselineFileWatches = { };

  baselineDirWatches = {
    dir_root = "/root";
  };

  baselineDirContentWatches = {
    persist_systemd_system = "/etc/systemd/system";
    persist_systemd_user = "/etc/systemd/user";
    persist_pam = "/etc/pam.d";
    persist_xdg_autostart = "/etc/xdg/autostart";
    persist_user_units = ".config/systemd/user";
    persist_user_units_share = ".local/share/systemd/user";
    persist_applications = ".local/share/applications";
  };

  baselineTreeWatches = { };

  baselineExtraRules = [ ];

  baselineExcludeMessageTypes = [ "BPF" ];

  watchAlways = path: lib.hasPrefix "!" path;

  auidUnset = "4294967295";

  resolveWatchPath =
    path:
    let
      p = lib.removePrefix "!" path;
    in
    if lib.hasPrefix "/" p then p else "${self.user.home}/${p}";
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
      description = "Audit -w watches for individual files injected by other modules.";
    };
    dirWatches = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Attribute-only watches on a single directory inode matching chmod and chown without recursion.";
    };
    dirContentWatches = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Audit -w watches on a directory that recurse into its whole subtree.";
    };
    treeWatches = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Recursive -F dir= subtree watches, the modern audit form preferred over the legacy -w watches.";
    };
    excludeMessageTypes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Audit message types injected by other modules to drop at the source via exclude rules.";
    };
    resolvedDirContentWatches = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Merged and resolved dir content watch paths set by the auditd module itself for consumption by other modules.";
    };
    resolvedTreeWatches = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Merged and resolved tree watch paths set by the auditd module itself for consumption by other modules.";
    };
  };

  module = {
    enabled =
      config:
      let
        hostWatches = if self ? host then self.host.settings.security.auditd.fileWatches else { };
        hostDirWatches = if self ? host then self.host.settings.security.auditd.dirWatches else { };
        hostExtraRules = if self ? host then self.host.settings.security.auditd.extraRules else [ ];
        injectedExtraRules = config.nx.linux.security.auditd.extraRules;
        injectedWatches = config.nx.linux.security.auditd.fileWatches;
        injectedDirWatches = config.nx.linux.security.auditd.dirWatches;
        hostDirContentWatches =
          if self ? host then self.host.settings.security.auditd.dirContentWatches else { };
        hostTreeWatches = if self ? host then self.host.settings.security.auditd.treeWatches else { };
        injectedDirContentWatches = config.nx.linux.security.auditd.dirContentWatches;
        injectedTreeWatches = config.nx.linux.security.auditd.treeWatches;
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
          ) (baselineExtraRules ++ hostExtraRules ++ injectedExtraRules)
        );
        watchPathByKey = baselineFileWatches // hostWatches // injectedWatches // extraRuleWatches;
        mergedDirWatches = baselineDirWatches // hostDirWatches // injectedDirWatches;
        mergedDirContentWatches =
          baselineDirContentWatches // hostDirContentWatches // injectedDirContentWatches;
        mergedTreeWatches = baselineTreeWatches // hostTreeWatches // injectedTreeWatches;
        fallbackExcludedKeys = lib.unique (
          lib.attrNames watchPathByKey
          ++ lib.attrNames mergedDirWatches
          ++ lib.attrNames mergedDirContentWatches
          ++ lib.attrNames mergedTreeWatches
          ++ [
            "modules"
            "access_denied"
          ]
        );
        fallbackExcludedKeyPattern = lib.concatMapStringsSep "|" (key: "${key}\"") fallbackExcludedKeys;
        watchActive = rawPath: if watchAlways rawPath then "always" else "outsideRebuild";
        userExtract = "auid=(?P<user>[0-9]+)";
        keyUserExtract = "auid=(?P<user>[0-9]+).*key=\"(?P<key>[a-zA-Z0-9_-]+)\"";
        uidNameMap =
          (lib.mapAttrs' (name: u: lib.nameValuePair (toString u.uid) name) (
            lib.filterAttrs (_name: u: u.uid != null && (u.uid >= 1000 || u.uid == 0)) config.users.users
          ))
          // {
            ${auidUnset} = "unset";
          };
        contentWatchString =
          key: rawPath:
          if watchAlways rawPath then
            "type=SYSCALL .*key=\"${key}\""
          else
            "type=SYSCALL (?!.*SYSCALL=(bind|unlink))"
            + (lib.optionalString (!lib.hasPrefix "/etc" (resolveWatchPath rawPath)) "(?!.*AUID=\"unset\")")
            + ".*key=\"${key}\"";
        watchPatterns = lib.mapAttrsToList (key: rawPath: {
          service = "auditd.service";
          tag = "audisp-syslog";
          string = "type=SYSCALL .*key=\"${key}\"";
          active = watchActive rawPath;
          hasPriority = !watchAlways rawPath;
          extract = userExtract;
          replacements.user = uidNameMap;
          mapping = {
            label = "Audit";
            title = "Watched File Changed";
            icon = "dialog-warning";
            priority = "warn";
            message = "{user} changed ${resolveWatchPath rawPath}";
          };
        }) watchPathByKey;
        dirWatchPatterns = lib.mapAttrsToList (key: rawPath: {
          service = "auditd.service";
          tag = "audisp-syslog";
          string = "type=SYSCALL .*key=\"${key}\"";
          active = watchActive rawPath;
          hasPriority = !watchAlways rawPath;
          extract = userExtract;
          replacements.user = uidNameMap;
          mapping = {
            label = "Audit";
            title = "Directory Attributes Changed";
            icon = "dialog-warning";
            priority = "warn";
            message = "{user} changed attributes of ${resolveWatchPath rawPath}";
          };
        }) mergedDirWatches;
        dirContentWatchPatterns = lib.mapAttrsToList (key: rawPath: {
          service = "auditd.service";
          tag = "audisp-syslog";
          string = contentWatchString key rawPath;
          active = watchActive rawPath;
          hasPriority = !watchAlways rawPath;
          extract = userExtract;
          replacements.user = uidNameMap;
          mapping = {
            label = "Audit";
            title =
              if lib.hasPrefix "persist_" key then
                "Persistence Location Changed"
              else
                "Directory Content Changed";
            icon = "dialog-warning";
            priority = "warn";
            message = "{user} changed contents of ${resolveWatchPath rawPath}";
          };
        }) mergedDirContentWatches;
        treeWatchPatterns = lib.mapAttrsToList (key: rawPath: {
          service = "auditd.service";
          tag = "audisp-syslog";
          string = contentWatchString key rawPath;
          active = watchActive rawPath;
          hasPriority = !watchAlways rawPath;
          extract = userExtract;
          replacements.user = uidNameMap;
          mapping = {
            label = "Audit";
            title = "Directory Tree Changed";
            icon = "dialog-warning";
            priority = "warn";
            message = "{user} changed a file under ${resolveWatchPath rawPath}";
          };
        }) mergedTreeWatches;
      in
      {
        nx.linux.security.auditd.resolvedDirContentWatches = lib.mapAttrs (
          key: resolveWatchPath
        ) mergedDirContentWatches;
        nx.linux.security.auditd.resolvedTreeWatches = lib.mapAttrs (
          key: resolveWatchPath
        ) mergedTreeWatches;

        nx.linux.monitoring.journal-watcher.highlightPatterns =
          watchPatterns
          ++ dirWatchPatterns
          ++ dirContentWatchPatterns
          ++ treeWatchPatterns
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
              string = "type=SYSCALL .*key=\"(?!(?:${fallbackExcludedKeyPattern}))[a-zA-Z0-9_-]+\"";
              active = "outsideRebuild";
              extract = keyUserExtract;
              replacements.user = uidNameMap;
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
        dirContentWatches,
        treeWatches,
        excludeMessageTypes,
        ...
      }:
      let
        auditdHost = self.host.settings.security.auditd;

        reservedKeys =
          lib.attrNames baselineFileWatches
          ++ lib.attrNames baselineDirWatches
          ++ lib.attrNames baselineDirContentWatches
          ++ lib.attrNames baselineTreeWatches
          ++ [
            "modules"
            "access_denied"
          ];

        hostWatchKeys =
          lib.attrNames auditdHost.fileWatches
          ++ lib.attrNames auditdHost.dirWatches
          ++ lib.attrNames auditdHost.dirContentWatches
          ++ lib.attrNames auditdHost.treeWatches;

        renderWatch = key: path: "-w ${path} -p wa -k ${key}";

        dirWatchSyscalls =
          if self.isAARCH64 then
            "fchmod,fchmodat,fchown,fchownat"
          else
            "chmod,fchmod,fchmodat,chown,fchown,lchown,fchownat";
        renderDirWatch =
          key: path:
          "-a always,exit -F arch=b64 -S ${dirWatchSyscalls} -F path=${path} -F filetype=dir -F auid!=${auidUnset} -k ${key}";

        renderTreeWatch = key: path: "-a always,exit -F dir=${path} -F perm=wa -k ${key}";

        baselineRules =
          lib.mapAttrsToList (key: path: renderWatch key (resolveWatchPath path)) baselineFileWatches
          ++ lib.mapAttrsToList (key: path: renderDirWatch key (resolveWatchPath path)) baselineDirWatches
          ++ lib.mapAttrsToList (key: path: renderWatch key (resolveWatchPath path)) baselineDirContentWatches
          ++ lib.mapAttrsToList (key: path: renderTreeWatch key (resolveWatchPath path)) baselineTreeWatches
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
        dirContentWatchRules = lib.mapAttrsToList (
          key: path: renderWatch key (resolveWatchPath path)
        ) auditdHost.dirContentWatches;
        treeWatchRules = lib.mapAttrsToList (
          key: path: renderTreeWatch key (resolveWatchPath path)
        ) auditdHost.treeWatches;
        injectedDirContentWatchRules = lib.mapAttrsToList (
          key: path: renderWatch key (resolveWatchPath path)
        ) dirContentWatches;
        injectedTreeWatchRules = lib.mapAttrsToList (
          key: path: renderTreeWatch key (resolveWatchPath path)
        ) treeWatches;

        openSyscalls = if self.isAARCH64 then "openat" else "open,openat";
        accessDeniedRulesList = lib.optionals auditdHost.accessDeniedRules [
          "-a always,exit -F arch=b64 -S ${openSyscalls} -F exit=-EACCES -F auid>=1000 -F auid!=${auidUnset} -k access_denied"
          "-a always,exit -F arch=b64 -S ${openSyscalls} -F exit=-EPERM -F auid>=1000 -F auid!=${auidUnset} -k access_denied"
        ];

        keyValid = key: builtins.match "[a-zA-Z0-9_-]+" key != null && builtins.stringLength key <= 31;

        watchPathNonEmpty = path: lib.removePrefix "!" path != "";

        excludeRules = map (t: "-a always,exclude -F msgtype=${t}") (
          lib.unique (baselineExcludeMessageTypes ++ auditdHost.excludeMessageTypes ++ excludeMessageTypes)
        );

        finalAuditRules = [
          "-i"
        ]
        ++ excludeRules
        ++ baselineRules
        ++ fileWatchRules
        ++ dirWatchRules
        ++ dirContentWatchRules
        ++ treeWatchRules
        ++ injectedWatchRules
        ++ injectedDirWatchRules
        ++ injectedDirContentWatchRules
        ++ injectedTreeWatchRules
        ++ accessDeniedRulesList
        ++ baselineExtraRules
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
            assertion = watchPathNonEmpty path;
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
            assertion = watchPathNonEmpty path;
            message = "auditd dirWatches path for key '${key}' must not be empty!";
          }) auditdHost.dirWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = keyValid key;
            message = "auditd dirContentWatches key '${key}' must match [a-zA-Z0-9_-]+ and be at most 31 characters long!";
          }) auditdHost.dirContentWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = !(lib.elem key reservedKeys);
            message = "auditd dirContentWatches key '${key}' collides with a reserved baseline key!";
          }) auditdHost.dirContentWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion =
              !(lib.elem key (lib.attrNames auditdHost.fileWatches ++ lib.attrNames auditdHost.dirWatches));
            message = "auditd dirContentWatches key '${key}' is also defined in fileWatches or dirWatches!";
          }) auditdHost.dirContentWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = watchPathNonEmpty path;
            message = "auditd dirContentWatches path for key '${key}' must not be empty!";
          }) auditdHost.dirContentWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = keyValid key;
            message = "auditd treeWatches key '${key}' must match [a-zA-Z0-9_-]+ and be at most 31 characters long!";
          }) auditdHost.treeWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = !(lib.elem key reservedKeys);
            message = "auditd treeWatches key '${key}' collides with a reserved baseline key!";
          }) auditdHost.treeWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion =
              !(lib.elem key (
                lib.attrNames auditdHost.fileWatches
                ++ lib.attrNames auditdHost.dirWatches
                ++ lib.attrNames auditdHost.dirContentWatches
              ));
            message = "auditd treeWatches key '${key}' is also defined in fileWatches, dirWatches or dirContentWatches!";
          }) auditdHost.treeWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = watchPathNonEmpty path;
            message = "auditd treeWatches path for key '${key}' must not be empty!";
          }) auditdHost.treeWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = keyValid key;
            message = "auditd injected fileWatches key '${key}' must match [a-zA-Z0-9_-]+ and be at most 31 characters long!";
          }) fileWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = !(lib.elem key (reservedKeys ++ hostWatchKeys));
            message = "auditd injected fileWatches key '${key}' collides with a reserved or host-defined key!";
          }) fileWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = watchPathNonEmpty path;
            message = "auditd injected fileWatches path for key '${key}' must not be empty!";
          }) fileWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = keyValid key;
            message = "auditd injected dirWatches key '${key}' must match [a-zA-Z0-9_-]+ and be at most 31 characters long!";
          }) dirWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = !(lib.elem key (reservedKeys ++ hostWatchKeys ++ lib.attrNames fileWatches));
            message = "auditd injected dirWatches key '${key}' collides with a reserved, host-defined or injected key!";
          }) dirWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = watchPathNonEmpty path;
            message = "auditd injected dirWatches path for key '${key}' must not be empty!";
          }) dirWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = keyValid key;
            message = "auditd injected dirContentWatches key '${key}' must match [a-zA-Z0-9_-]+ and be at most 31 characters long!";
          }) dirContentWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion =
              !(lib.elem key (
                reservedKeys ++ hostWatchKeys ++ lib.attrNames fileWatches ++ lib.attrNames dirWatches
              ));
            message = "auditd injected dirContentWatches key '${key}' collides with a reserved, host-defined or injected key!";
          }) dirContentWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = watchPathNonEmpty path;
            message = "auditd injected dirContentWatches path for key '${key}' must not be empty!";
          }) dirContentWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = keyValid key;
            message = "auditd injected treeWatches key '${key}' must match [a-zA-Z0-9_-]+ and be at most 31 characters long!";
          }) treeWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion =
              !(lib.elem key (
                reservedKeys
                ++ hostWatchKeys
                ++ lib.attrNames fileWatches
                ++ lib.attrNames dirWatches
                ++ lib.attrNames dirContentWatches
              ));
            message = "auditd injected treeWatches key '${key}' collides with a reserved, host-defined or injected key!";
          }) treeWatches
          ++ lib.mapAttrsToList (key: path: {
            assertion = watchPathNonEmpty path;
            message = "auditd injected treeWatches path for key '${key}' must not be empty!";
          }) treeWatches;

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

        systemd.services.audit-rules-nixos = {
          after = [ "local-fs.target" ];
          restartIfChanged = lib.mkIf auditdHost.locked false;
          serviceConfig.ExecStopPost = lib.mkIf auditdHost.locked (lib.mkForce [ ]);
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
