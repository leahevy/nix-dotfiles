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
  name = "journal-watcher";

  group = "monitoring";
  input = "linux";

  options =
    let
      mkPatternSubmodule =
        withHighlightFields:
        lib.types.submodule {
          options = {
            service = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Systemd unit name to match (exact match, escaped).";
            };
            tag = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Syslog identifier to match (exact match, escaped).";
            };
            string = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Message content to match (regex pattern).";
            };
            user = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Match user services. Service field matches inner service from user@UID messages.";
            };
            kernel = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Match kernel transport messages only.";
            };
            unitless = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Match messages without a systemd unit (excluding kernel transport).";
            };
            all = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Match messages in all scopes. Expanded to four patterns: plain, kernel, user, and unitless. Mutually exclusive with kernel, user, and unitless.";
            };
          }
          // lib.optionalAttrs withHighlightFields {
            label = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Replace the [User]/[NixOS]/[Kernel] bracket with [{label}] when this highlight pattern matches.";
            };
            title = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Replace the suffix part of the notification title when this highlight pattern matches.";
            };
          };
        };
    in
    {
      ignorePatterns = lib.mkOption {
        type = lib.types.listOf (mkPatternSubmodule false);
        default = [ ];
        description = "Compound ignore patterns. All specified fields must match (AND logic).";
      };
      highlightPatterns = lib.mkOption {
        type = lib.types.listOf (mkPatternSubmodule true);
        default = [ ];
        description = "Compound highlight patterns. All specified fields must match (AND logic).";
      };
    };

  settings = {
    baseIgnorePatterns = [ ];
    ignorePatterns = [ ];

    baseHighlightPatterns = [
      {
        tag = "nixos";
        user = true;
        label = "NixOS";
        title = "System Switch";
      }
    ];
    highlightPatterns = [ ];

    baseSystemServicesToIgnore = [
      "nx-journal-watcher"
    ];
    additionalSystemServicesToIgnore = [ ];

    baseUserServicesToIgnore = [ ];
    additionalUserServicesToIgnore = [ ];

    baseTagsToIgnore = [ ];
    additionalTagsToIgnore = [ ];

    baseStringsToIgnore = [
      "PV /dev/dm-.* online, VG .* is complete"
      "VG .* finished"
      "Activation request for .* failed: The systemd unit .* could not be found"
      "Ignoring duplicate name"
      "Failed to activate with specified passphrase\\. \\(Passphrase incorrect\\?\\)"
      "File /var/log/journal/.* corrupted or uncleanly shut down, renaming and replacing"
      "Failed to read journal file .* for rotation.*Device or resource busy"
      "Failed to initialize pidref: No such process"
      "Couldn't find existing drive object for device.*uevent action 'change'"
      "Partitions found on device '/dev/sd[a-z]+' but couldn't read partition table signature.*No such device or address"
      "profiles/audio/bap\\.c:.*BAP requires ISO Socket which is not enabled"
      "bap: Operation not supported \\([0-9]+\\)"
      "Failed to set mode: Failed \\(0x[0-9a-fA-F]+\\)"
      "KD_FONT_OP_GET failed while trying to get the font metadata: Invalid argument"
      "Fonts will not be copied to remaining consoles"
    ];
    additionalStringsToIgnore = [ ];

    baseSystemStringsToIgnore = [ ];
    additionalSystemStringsToIgnore = [ ];

    baseKernelStringsToIgnore = [
      "Failed to make /usr/ a mount point, ignoring"
      "Failed to get EXE, ignoring: No such process"
      "USB Audio.*cannot get freq"
      "USB Audio.*cannot set freq"
      "usb.*Unable to submit urb.*at snd_usb_queue_pending_output_urbs"
      "usb.*cannot submit urb.*error.*no device"
      "\\[Firmware Bug\\]: TSC_DEADLINE disabled due to Errata"
      "x86/cpu: .*disabled by BIOS"
      "x86/cpu: .*disabled or unsupported by BIOS"
      "ENERGY_PERF_BIAS: Set to '.*', was '.*'"
      "CPU bug present and SMT on"
      "ata.*supports DRM functions and may not be fully accessible"
      "sd.*No Caching mode page found"
      "sd.*Assuming drive cache: write through"
      "usb.*Warning! Unlikely big volume range.*cval->res is probably wrong"
      "usb.*current rate.*is different from the runtime rate"
      "usb.*\\[.*\\] FU \\[.*Volume\\] ch ="
      "module .*taints kernel"
      "resource: resource sanity check: requesting.*which spans more than pnp"
      "caller get_primary_reg_base.*mapping multiple BARs"
      "I/O error, dev sr[0-9]+, sector.*op.*READ.*flags.*phys_seg.*prio class"
      "Buffer I/O error on dev sr[0-9]+, logical block.*async page read"
      "blk_print_req_error: [0-9]+ callbacks suppressed"
      ".*: loading out-of-tree module taints kernel"
      "^\\*+\\s*NOTICE NOTICE NOTICE.*\\s*\\*+$"
      "^\\*+\\s*trace_printk\\(\\) being used.*\\s*\\*+$"
      "^\\*+\\s*This means that this is a DEBUG kernel.*\\s*\\*+$"
      "^\\*+\\s*unsafe for production use.*\\s*\\*+$"
      "^\\*+\\s*If you see this message and you are not debugging.*\\s*\\*+$"
      "^\\*+\\s*the kernel, report this immediately to your vendor.*\\s*\\*+$"
      "buffer_io_error: [0-9]+ callbacks suppressed"
      "hrtimer: interrupt took [0-9]+ ns"
      "usb .*device descriptor read/([0-9]+|all), error -[0-9]+"
      "usb.*cannot disable \\(err = -[0-9]+\\)"
      "usb.*cannot submit urb.*err = -[0-9]+"
      "usb.*cannot reset.*err = -[0-9]+"
      "usb.*cannot get freq at ep"
      "usb.*usb_set_interface failed"
      "xhci_hcd.*Timeout while waiting for setup device command"
      "xhci_hcd.*Trying to add endpoint.*without dropping it"
      "usb.*device not accepting address.*error -[0-9]+"
      "usb.*WARN: invalid context state for evaluate context command"
      "usb.*Device not responding to setup address"
      "usb.*unable to enumerate USB device"
      "uvcvideo.*UVC non compliance.*max payload transmission size.*exceeds.*ep max packet.*Using the max size"
      "hub.*config failed, can't get hub status \\(err -[0-9]+\\)"
      "uvcvideo.*Failed to query \\([0-9]+\\) UVC probe control.*\\(exp\\. [0-9]+\\)\\."
      "uvcvideo.*Failed to initialize the device \\(-[0-9]+\\)\\."
      "usb.*Failed to query.*UVC control.*"
      "usb.*cannot set freq [0-9]+ to ep"
      "usb.*failed to get current value for ch [0-9]+ \\(-[0-9]+\\)"
      "usb.*cannot get min/max values for control [0-9]+ \\(id [0-9]+\\)"
      "usb.*couldn't allocate usb_device"
      "usb.*can't set config #[0-9]+, error -[0-9]+"
      "usb.*Cannot enable\\. Maybe the USB cable is bad\\?"
      "usb.*Not enough bandwidth for new device state"
      "usb.*disabled by hub \\(EMI\\?\\), re-enabling"
      "VMSCAPE: SMT on, STIBP is required for full protection"
      "hub.*hub_ext_port_status failed \\(err = -[0-9]+\\)"
      "usb.*Failed to suspend device, error -[0-9]+"
      "usb.*clear tt [0-9]+ \\([0-9a-fA-F]+\\) error -[0-9]+"
      "usbhid.*can't add hid device: -[0-9]+"
      "usbhid.*probe with driver usbhid failed with error -[0-9]+"
      "^[^a-zA-Z]*$"
      "^-+\\[ cut here \\]-+$"
      "^---\\[ end trace [0-9a-f]+ \\]---$"
      "^Call Trace:$"
      "^ <TASK>$"
      "^ </TASK>$"
      "^Code: [0-9a-f ]+$"
      "^RAX: [0-9a-f]+ RBX: [0-9a-f]+ RCX: [0-9a-f]+$"
      "^RDX: [0-9a-f]+ RSI: [0-9a-f]+ RDI: [0-9a-f]+$"
      "^RBP: [0-9a-f]+ R08: [0-9a-f]+ R09: [0-9a-f]+$"
      "^R10: [0-9a-f]+ R11: [0-9a-f]+ R12: [0-9a-f]+$"
      "^R13: [0-9a-f]+ R14: [0-9a-f]+ R15: [0-9a-f]+$"
      "^RSP: [0-9a-f]+ EFLAGS: [0-9a-f]+$"
      "^FS: .* GS:.* knlGS:.*$"
      "^CS: .* DS: .* ES: .* CR0: [0-9a-f]+$"
      "^CR2: [0-9a-f]+ CR3: [0-9a-f]+ CR4: [0-9a-f]+$"
      "^Modules linked in:.*$"
      "^ [a-z][a-z0-9_]+(\\([A-Z]+\\))?( [a-z][a-z0-9_]+(\\([A-Z]+\\))?)+$"
      "^ (\\? )?[a-zA-Z_][a-zA-Z0-9_]*\\+0x[0-9a-f]+/0x[0-9a-f]+( \\[[a-z_]+\\])?$"
    ];
    additionalKernelStringsToIgnore = [ ];

    baseUserStringsToIgnore = [ ];
    additionalUserStringsToIgnore = [ ];

    baseStringsToHighlight = [ ];
    additionalStringsToHighlight = [ ];

    baseSystemStringsToHighlight = [ ];
    additionalSystemStringsToHighlight = [ ];

    baseKernelStringsToHighlight = [ ];
    additionalKernelStringsToHighlight = [ ];

    baseUserStringsToHighlight = [ ];
    additionalUserStringsToHighlight = [ ];

    baseTagsToHighlight = [ ];
    additionalTagsToHighlight = [ ];

    debug = false;
    dev = false;
    ignoreUserServicesForPushover = true;
    pushoverRateLimit = 10;
    pushoverRateLimitUnknown = 30;
    sameMessageRateLimitMinutes = 15;
  };

  on = {
    system =
      config:
      let
        pushover = config.nx.linux.notifications.pushover;

        opts = self.options config;

        allSystemServicesToIgnore =
          self.settings.baseSystemServicesToIgnore ++ self.settings.additionalSystemServicesToIgnore;

        allUserServicesToIgnore =
          self.settings.baseUserServicesToIgnore ++ self.settings.additionalUserServicesToIgnore;

        allTagsToIgnore = self.settings.baseTagsToIgnore ++ self.settings.additionalTagsToIgnore;

        allStringsToIgnore = self.settings.baseStringsToIgnore ++ self.settings.additionalStringsToIgnore;

        allSystemStringsToIgnore =
          self.settings.baseSystemStringsToIgnore ++ self.settings.additionalSystemStringsToIgnore;

        allKernelStringsToIgnore =
          self.settings.baseKernelStringsToIgnore ++ self.settings.additionalKernelStringsToIgnore;

        allUserStringsToIgnore =
          self.settings.baseUserStringsToIgnore ++ self.settings.additionalUserStringsToIgnore;

        allStringsToHighlight =
          self.settings.baseStringsToHighlight ++ self.settings.additionalStringsToHighlight;

        allSystemStringsToHighlight =
          self.settings.baseSystemStringsToHighlight ++ self.settings.additionalSystemStringsToHighlight;

        allKernelStringsToHighlight =
          self.settings.baseKernelStringsToHighlight ++ self.settings.additionalKernelStringsToHighlight;

        allUserStringsToHighlight =
          self.settings.baseUserStringsToHighlight ++ self.settings.additionalUserStringsToHighlight;

        allTagsToHighlight = self.settings.baseTagsToHighlight ++ self.settings.additionalTagsToHighlight;

        mkPattern =
          {
            service ? null,
            tag ? null,
            string ? null,
            user ? false,
            kernel ? false,
            unitless ? false,
            all ? false,
          }:
          {
            inherit
              service
              tag
              string
              user
              kernel
              unitless
              all
              ;
          };

        expandPattern =
          pat:
          if pat.all or false then
            map (flags: (builtins.removeAttrs pat [ "all" ]) // flags) [
              { }
              { kernel = true; }
              { user = true; }
              { unitless = true; }
            ]
          else
            [ (builtins.removeAttrs pat [ "all" ]) ];

        validatePatterns =
          label: patterns:
          lib.concatMap (
            pat:
            let
              b = v: if v then "true" else "false";
              q = v: if v == null then "null" else "\"${v}\"";
              s = pat.service or null;
              t = pat.tag or null;
              str = pat.string or null;
              u = pat.user or false;
              k = pat.kernel or false;
              ul = pat.unitless or false;
              a = pat.all or false;
              desc = "service=${q s} tag=${q t} string=${q str} user=${b u} kernel=${b k} unitless=${b ul} all=${b a}";
            in
            [
              {
                assertion = s != null || t != null || str != null;
                message = "journal-watcher ${label}: at least one of service/tag/string must be set: { ${desc} }";
              }
              {
                assertion = !(u && k);
                message = "journal-watcher ${label}: user=true and kernel=true are mutually exclusive: { ${desc} }";
              }
              {
                assertion = !(k && ul);
                message = "journal-watcher ${label}: kernel=true and unitless=true are mutually exclusive: { ${desc} }";
              }
              {
                assertion = !(a && k);
                message = "journal-watcher ${label}: all=true and kernel=true are mutually exclusive: { ${desc} }";
              }
              {
                assertion = !(a && u);
                message = "journal-watcher ${label}: all=true and user=true are mutually exclusive: { ${desc} }";
              }
              {
                assertion = !(a && ul);
                message = "journal-watcher ${label}: all=true and unitless=true are mutually exclusive: { ${desc} }";
              }
            ]
          ) patterns;

        allIgnorePatterns = lib.concatMap expandPattern (
          self.settings.baseIgnorePatterns
          ++ (map (s: mkPattern { service = s; }) allSystemServicesToIgnore)
          ++ (map (
            s:
            mkPattern {
              service = s;
              user = true;
            }
          ) allUserServicesToIgnore)
          ++ (map (
            t:
            mkPattern {
              tag = t;
              all = true;
            }
          ) allTagsToIgnore)
          ++ (map (
            s:
            mkPattern {
              string = s;
              all = true;
            }
          ) allStringsToIgnore)
          ++ (map (s: mkPattern { string = s; }) allSystemStringsToIgnore)
          ++ (map (
            s:
            mkPattern {
              string = s;
              kernel = true;
            }
          ) allKernelStringsToIgnore)
          ++ (map (
            s:
            mkPattern {
              string = s;
              user = true;
            }
          ) allUserStringsToIgnore)
          ++ self.settings.ignorePatterns
          ++ opts.ignorePatterns
        );
        ignorePatternsJson = pkgs.writeText "journal-watcher-ignore-patterns.json" (
          builtins.toJSON allIgnorePatterns
        );

        allHighlightPatterns = lib.concatMap expandPattern (
          self.settings.baseHighlightPatterns
          ++ (map (
            s:
            mkPattern {
              string = s;
              all = true;
            }
          ) allStringsToHighlight)
          ++ (map (s: mkPattern { string = s; }) allSystemStringsToHighlight)
          ++ (map (
            s:
            mkPattern {
              string = s;
              kernel = true;
            }
          ) allKernelStringsToHighlight)
          ++ (map (
            s:
            mkPattern {
              string = s;
              user = true;
            }
          ) allUserStringsToHighlight)
          ++ (map (
            t:
            mkPattern {
              tag = t;
              all = true;
            }
          ) allTagsToHighlight)
          ++ self.settings.highlightPatterns
          ++ opts.highlightPatterns
        );
        highlightPatternsJson = pkgs.writeText "journal-watcher-highlight-patterns.json" (
          builtins.toJSON allHighlightPatterns
        );

        stateDir = "/var/lib/nx-journal-watcher";
        rateLimitStateDir = "${stateDir}/rate-limits";
        cursorFile = "${stateDir}/journal-cursor";
        messageHashesFile = "${stateDir}/message-hashes";

        pushoverCmd =
          if self.isModuleEnabled "notifications.pushover" && pushover.script != null then
            pushover.sendList {
              title = "{title_text_pushover}";
              message = "{message_text_pushover}";
              type = "{notify_type}";
            }
          else
            [ ];

        watcherConfigJson = pkgs.writeText "journal-watcher-config.json" (
          builtins.toJSON {
            state_dir = stateDir;
            rate_limit_state_dir = rateLimitStateDir;
            cursor_file = cursorFile;
            message_hashes_file = messageHashesFile;
            rate_limit_per_hour = self.settings.pushoverRateLimit;
            rate_limit_per_hour_unknown = self.settings.pushoverRateLimitUnknown;
            message_rate_limit_minutes = self.settings.sameMessageRateLimitMinutes;
            user_notify_enabled = self.isModuleEnabled "notifications.user-notify";
            pushover_enabled = self.isModuleEnabled "notifications.pushover" && pushover.script != null;
            debug_enabled = self.settings.debug;
            dev_enabled = self.settings.dev;
            ignore_user_services_for_pushover = self.settings.ignoreUserServicesForPushover;
            main_user_uid = config.users.users.${self.host.mainUser.username}.uid;
            journalctl_bin = "${pkgs.systemd}/bin/journalctl";
            logger_bin = "${pkgs.util-linux}/bin/logger";
            pushover_cmd = pushoverCmd;
            ignore_patterns = allIgnorePatterns;
            highlight_patterns = allHighlightPatterns;
          }
        );

        monitorScript = self.file "monitor.py";

        regexValidation = pkgs.runCommand "journal-watcher-regex-validation" { } ''
          ${pkgs.python3}/bin/python3 ${pkgs.writeText "validate-regexes.py" ''
            import json, os, re, sys
            def fmt_pat(pat):
              active = {k: v for k, v in pat.items() if v is not None and v is not False}
              return json.dumps(active)
            errors = []
            for path in sys.argv[1:]:
              label = os.path.basename(path).replace("journal-watcher-", "").replace(".json", "")
              with open(path) as f:
                patterns = json.load(f)
              for pat in patterns:
                s = pat.get("string")
                if s is not None:
                  try:
                    re.compile(s)
                  except re.error as e:
                    errors.append(f"  [{label}] {fmt_pat(pat)}: {e}")
            if errors:
              print("journal-watcher: invalid regex patterns:", file=sys.stderr)
              for e in errors:
                print(e, file=sys.stderr)
              sys.exit(1)
          ''} ${ignorePatternsJson} ${highlightPatternsJson}
          touch $out
        '';
      in
      {
        assertions =
          validatePatterns "ignorePatterns" (
            self.settings.baseIgnorePatterns ++ opts.ignorePatterns ++ self.settings.ignorePatterns
          )
          ++ validatePatterns "highlightPatterns" (
            self.settings.baseHighlightPatterns ++ opts.highlightPatterns ++ self.settings.highlightPatterns
          );

        systemd.services.nx-journal-watcher = {
          description = "NX System Journal Watcher";

          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-journald.service" ];

          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RestartSec = "10";
            User = "root";
            Group = "root";
            ExecStart = "${pkgs.python3}/bin/python3 ${monitorScript} ${watcherConfigJson}";
            ExecStartPre = [
              "${pkgs.coreutils}/bin/rm -f ${messageHashesFile}"
              "${pkgs.coreutils}/bin/rm -rf ${rateLimitStateDir}"
            ];

            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [ "/var/lib/nx-journal-watcher" ];

            MemoryMax = "100M";
            CPUQuota = "10%";
          };

          path =
            with pkgs;
            [
              python3
              systemd
              util-linux
            ]
            ++ lib.optionals (pushover.script != null) [ pushover.script ];
        };

        system.extraDependencies = [ regexValidation ];

        environment.persistence."${self.persist.system}" = {
          directories = [
            "/var/lib/nx-journal-watcher"
          ];
        };
      };
  };
}
