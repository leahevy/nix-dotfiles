args@{
  lib,
  pkgs,
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
      mkMappingSubmodule = lib.types.submodule {
        options = {
          icon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Default icon, used when no priority-specific icon is set.";
          };
          infoIcon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Icon for info-level notifications.";
          };
          warnIcon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Icon for warning-level notifications.";
          };
          failedIcon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Icon for failed-level notifications.";
          };
          emergIcon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Icon for emergency-level notifications.";
          };
          label = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override the bracket label. Empty string omits the bracket entirely.";
          };
          title = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override the title suffix.";
          };
          message = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override the notification message body, with {name} placeholders when the pattern defines an extract regex.";
          };
          priority = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.enum [
                "info"
                "warn"
                "failed"
                "emerg"
              ]
            );
            default = null;
            description = "Override notification priority.";
          };
        };
      };

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
            active = lib.mkOption {
              type = lib.types.enum [
                "always"
                "never"
                "duringRebuild"
                "outsideRebuild"
              ];
              default = "always";
              description = "Controls whether the pattern applies always, never, only during a system rebuild window, or only outside one.";
            };
          }
          // lib.optionalAttrs withHighlightFields {
            mapping = lib.mkOption {
              type = lib.types.nullOr mkMappingSubmodule;
              default = null;
              description = "Optional notification overrides applied when this highlight pattern matches.";
            };
            channels = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.submodule {
                  options = {
                    pushover = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Send to pushover. null = scope default (true for system, false for user when ignore_user_services_for_pushover is set).";
                    };
                    user = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Send desktop notification. null = always enabled.";
                    };
                  };
                }
              );
              default = null;
              description = "Override notification channels for this highlight pattern. null fields use scope-based defaults.";
            };
            ignoreRateLimiting = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Ignore message dedup rate limiting for this highlight pattern.";
            };
            extract = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional regex with named groups run against the matched message to fill {name} placeholders in the mapping message, falling back to the raw message when it does not match.";
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
      tagMappings = lib.mkOption {
        type = lib.types.attrsOf mkMappingSubmodule;
        default = { };
        description = "Per-tag overrides for notification icon, bracket, title, and message.";
      };
      debug = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      ignoreUserServicesForPushover = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      forceEnableUserServicesForPushoverOnHeadless = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      pushoverRateLimit = lib.mkOption {
        type = lib.types.int;
        default = 10;
      };
      pushoverRateLimitUnknown = lib.mkOption {
        type = lib.types.int;
        default = 30;
      };
      highlightRateLimit = lib.mkOption {
        type = lib.types.int;
        default = 100;
      };
      sameMessageRateLimitMinutes = lib.mkOption {
        type = lib.types.int;
        default = 15;
      };
      rebuildWindowTimeoutSeconds = lib.mkOption {
        type = lib.types.int;
        default = 180;
      };
    };

  module =
    let
      baseIgnorePatterns = [
        {
          service = "init.scope";
          tag = "systemd";
          string = "nix-daemon\\.service: Found left-over process [0-9]+ \\(nix-daemon\\) in control group while starting unit\\.";
        }
        {
          service = "init.scope";
          tag = "systemd";
          string = "nix-daemon\\.service: This usually indicates unclean termination of a previous run, or service implementation deficiencies\\.";
        }
        {
          tag = "systemd-coredump";
          string = "of user 3[0-9]{4} terminated abnormally";
          all = true;
        }
        {
          tag = "systemd";
          string = "Failed with result 'exit-code'\\.";
          user = true;
        }
      ];
      baseHighlightPatterns = [
        {
          tag = "nixos";
          string = "switching to system configuration";
          all = true;
          ignoreRateLimiting = true;
          extract = "(?P<state>finished switching|switching) to system configuration /nix/store/[a-z0-9]+-nixos-system-(?P<generation>\\S+?)(?P<failed> failed \\(status [0-9]+\\))?$";
          channels = {
            pushover =
              if
                helpers.isDeploymentMode self [
                  "server"
                  "managed"
                ]
              then
                null
              else
                false;
          };
          mapping = {
            label = "NixOS";
            title = "System Switch";
            icon = "applications-science";
            message = "{state} to {generation}{failed}";
          };
        }
      ];
      baseTagMappings = { };
      baseSystemServicesToIgnore = [
        "nx-journal-watcher"
      ];
      baseUserServicesToIgnore = [ ];
      baseTagsToIgnore = [ ];
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
        "mm_reap: child terminated by signal 15"
        "Failed to resolve group 'sudo': No such process"
      ];
      baseSystemStringsToIgnore = [
        "Error re-reading partition table \\(BLKRRPART ioctl\\) on /dev/[a-z]+: Device or resource busy"
        "Ignoring SCSI command SYNCHRONIZE CACHE failure.*on /dev/[a-z]+"
      ];
      baseKernelStringsToIgnore = [
        "hpet_acpi_add: no address or irqs in _CRS"
        "r8169 [0-9a-f:.]+: can't disable ASPM; OS doesn't have ASPM control"
        "ACPI Error: AE_NOT_FOUND, While resolving a named reference package element - \\\\_SB_\\.PC00\\.LPCB\\.H_EC\\.TFN1"
        "pnp 00:02: disabling \\[mem 0x[0-9a-f]+-0x[0-9a-f]+\\] because it overlaps 0000:00:02\\.0 BAR 9"
        "caller igen6_probe\\+0x[0-9a-f]+/0x[0-9a-f]+ \\[igen6_edac\\] mapping multiple BARs"
        "ACPI Warning: \\\\_SB\\.IETM\\._ART: Found unexpected NULL package element"
        "ACPI Warning: \\\\_SB\\.IETM\\._ART: Missing expected return value"
        "ACPI Warning: \\\\_SB\\.IETM\\._ART: Expected return object of type Reference"
        "_ART package [0-9]+ is invalid, ignored"
        "spi-nor spi0\\.0: supply vcc not found, using dummy regulator"
        "nvme nvme[0-9]+: using unchecked data buffer"
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
        "FAT-fs \\([a-z0-9]+\\): unable to read boot sector to mark fs as dirty"
        "hrtimer: interrupt took [0-9]+ ns"
        "usb .*device descriptor read/([0-9]+|all), error -[0-9]+"
        "usb.*cannot disable \\(err = -[0-9]+\\)"
        "usb.*cannot submit urb.*err = -[0-9]+"
        "usb.*cannot reset.*err = -[0-9]+"
        "usb.*cannot get freq at ep"
        "usb.*usb_set_interface failed"
        "xhci_hcd.*Timeout while waiting for setup device command"
        "xhci_hcd.*Trying to add endpoint.*without dropping it"
        "xhci_hcd.*ERROR Transfer event for disabled endpoint slot [0-9]+ ep [0-9]+"
        "xhci_hcd 0000:[0-9a-f:.]+: @[0-9a-f]+ [0-9a-f]+ [0-9a-f]+ [0-9a-f]+ [0-9a-f]+"
        "usb.*device not accepting address.*error -[0-9]+"
        "usb.*WARN: invalid context state for evaluate context command"
        "usb.*Device not responding to setup address"
        "usb.*unable to enumerate USB device"
        "uvcvideo.*UVC non compliance.*max payload transmission size.*exceeds.*ep max packet.*Using the max size"
        "uvcvideo.*UVC non compliance: Reducing max payload transfer size \\([0-9]+\\) to fit endpoint limit \\([0-9]+\\)\\."
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
        "hid-generic [0-9a-fA-F]{4}:[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\\.[0-9a-fA-F]{4}: unknown main item tag 0x[0-9a-f]+"
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
        "^CS: .* DS: .* ES: .* CR.*: [0-9a-f]+$"
        "^CR2: [0-9a-f]+ CR3: [0-9a-f]+ CR4: [0-9a-f]+$"
        "^Modules linked in:.*$"
        "^ (?:[a-z0-9_]+(\([A-Z]+\))?)( (?:[a-z0-9_]+(\([A-Z]+\))?))*$"
        "^ (\\? )?[a-zA-Z_][a-zA-Z0-9_]*\\+0x[0-9a-f]+/0x[0-9a-f]+( \\[[a-z_]+\\])?$"
        "^\\s*(?:[A-Za-z0-9_]+(?:\\([A-Z]\\))?\\s+){10,}[A-Za-z0-9_]+(?:\\([A-Z]\\))?\\s*$"
        "^CPU: .*Tainted:.*$"
        "^Tainted: .*"
        "^Hardware name: .*"
        "^RIP: .*"
        "^RSP: .*"
        "^Code: .*"
        "^\\s*[A-Za-z0-9_\\.]+\\+0x[0-9a-f]+/0x[0-9a-f]+$"
        "^\\[drm:.*\\].*$"
        "^.*drm_WARN_ON.*$"
        "^Call trace:$"
        "^CPU: [0-9]+ (UID: [0-9]+ )?PID: [0-9]+ Comm: .*$"
        "^Workqueue: .*$"
        "^pstate: [0-9a-f]+ \\(.*\\)$"
        "^pc : .*$"
        "^lr : .*$"
        "^sp : [0-9a-f]+$"
        "^x[0-9]+ *: [0-9a-f]+.*$"
        "prepare_slab_obj_exts_hook, [A-Za-z0-9_-]+: Failed to create slab extension vector!"
        "WARNING: CPU: [0-9]+ PID: [0-9]+ at mm/slub\\.c:[0-9]+ alloc_tagging_slab_alloc_hook"
        "device-mapper: core: CONFIG_IMA_DISABLE_HTABLE is disabled\\. Duplicate IMA measurements will not be recorded in the IMA log\\."
        "uvcvideo.*: Failed to query \\(GET_INFO\\) UVC control [0-9]+ on unit [0-9]+:.*\\(exp\\. [0-9]+\\)\\."
        "^.+ invoked oom-killer: gfp_mask=0x[0-9a-fA-F]+"
        "^Tasks state \\(memory values in pages\\):$"
        "^\\[  pid  \\]"
        "^\\[[ 0-9]+\\][ 0-9]"
        "^oom-kill:constraint="
        "^Mem-Info:$"
        "^active_anon:[0-9]+ inactive_anon:[0-9]+"
        "^\\s+(active_file|isolated_anon|isolated_file|unevictable|dirty|writeback|slab_reclaimable|slab_unreclaimable|mapped|shmem|pagetables|sec_pagetables|bounce|kernel_misc_reclaimable|free):[0-9]+"
        "^Node [0-9]+ (active_anon|DMA free|Normal free):[0-9]+"
        "^Node [0-9]+ (DMA|Normal): [0-9]+\\*[0-9]+kB"
        "^[0-9]+ total pagecache pages$"
        "^[0-9]+ pages in swap cache$"
        "^Free swap  = [0-9]+kB$"
        "^Total swap = [0-9]+kB$"
        "^[0-9]+ pages RAM$"
        "^[0-9]+ pages HighMem/MovableOnly$"
        "^[0-9]+ pages reserved$"
        "^[0-9]+ pages cma reserved$"
        "^[0-9]+ pages hwpoisoned$"
        "^lowmem_reserve\\[\\]:"
      ];
      baseUserStringsToIgnore = [ ];
      baseStringsToHighlight = [ ];
      baseSystemStringsToHighlight = [ ];
      baseKernelStringsToHighlight = [ ];
      baseUserStringsToHighlight = [ ];
      baseTagsToHighlight = [ ];
    in
    {
      enabled =
        config:
        let
          hasDataDrive = config.nx.linux.storage."luks-data-drive".enable;
          removableDev = if hasDataDrive then "sd[c-z]" else "sd[b-z]";
        in
        {
          nx.linux.monitoring.journal-watcher.ignorePatterns = [
            {
              kernel = true;
              string = "EXT4-fs \\(${removableDev}[0-9]*\\): shut down requested \\([0-9]+\\)";
            }
            {
              kernel = true;
              string = "Aborting journal on device ${removableDev}[0-9]*-[0-9]+\\.";
            }
            {
              kernel = true;
              string = "device offline error, dev ${removableDev}, sector [0-9]+";
            }
            {
              kernel = true;
              string = "Buffer I/O error on dev ${removableDev}[0-9]+, logical block [0-9]+, lost sync page write";
            }
            {
              kernel = true;
              string = "Buffer I/O error on dev ${removableDev}[0-9]+, logical block [0-9]+, lost async page write";
            }
            {
              kernel = true;
              string = "JBD2: I/O error when updating journal superblock for ${removableDev}[0-9]*-[0-9]+\\.";
            }
            {
              kernel = true;
              string = "EXT4-fs \\(${removableDev}[0-9]*\\): I/O error while writing superblock";
            }
            {
              kernel = true;
              string = "EXT4-fs \\(${removableDev}[0-9]*\\): bad geometry: block count [0-9]+ exceeds size of device \\([0-9]+ blocks\\)";
            }
            {
              kernel = true;
              string = "FAT-fs \\(${removableDev}[0-9]*\\): Volume was not properly unmounted\\.";
            }
          ];
        };

      system =
        config:
        let
          pushover = config.nx.linux.notifications.pushover;
          hcFinalUrl = config.nx.linux.server.healthchecks.healthchecksFinalChecksURL;
          hcBaseUrl = config.nx.linux.server.healthchecks.healthchecksBaseUrl;
          hcRegularUUID = config.nx.linux.server.healthchecks.builtinHealthCheckUUIDs.regular;
          hcUrl =
            if hcRegularUUID != null && hcFinalUrl != null then
              "${hcBaseUrl}/checks/${hcRegularUUID}/details/"
            else
              hcFinalUrl;
          hcUrlTitle =
            if hcUrl == null then
              null
            else if hcRegularUUID != null && hcFinalUrl != null then
              "View check"
            else
              "View healthchecks";

          opts = self.options config;

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
                {
                  assertion =
                    (pat.extract or null) == null
                    || ((pat.mapping or null) != null && (pat.mapping.message or null) != null);
                  message = "journal-watcher ${label}: extract requires mapping.message to be set: { ${desc} }";
                }
              ]
            ) patterns;

          allIgnorePatterns = map (p: p // { pattern_type = "ignore"; }) (
            lib.concatMap expandPattern (
              baseIgnorePatterns
              ++ (map (s: mkPattern { service = s; }) baseSystemServicesToIgnore)
              ++ (map (
                s:
                mkPattern {
                  service = s;
                  user = true;
                }
              ) baseUserServicesToIgnore)
              ++ (map (
                t:
                mkPattern {
                  tag = t;
                  all = true;
                }
              ) baseTagsToIgnore)
              ++ (map (
                s:
                mkPattern {
                  string = s;
                  all = true;
                }
              ) baseStringsToIgnore)
              ++ (map (s: mkPattern { string = s; }) baseSystemStringsToIgnore)
              ++ (map (
                s:
                mkPattern {
                  string = s;
                  kernel = true;
                }
              ) baseKernelStringsToIgnore)
              ++ (map (
                s:
                mkPattern {
                  string = s;
                  user = true;
                }
              ) baseUserStringsToIgnore)
              ++ opts.ignorePatterns
            )
          );
          ignorePatternsJson = pkgs.writeText "journal-watcher-ignore-patterns.json" (
            builtins.toJSON allIgnorePatterns
          );

          serverManagedHighlightPatterns =
            lib.optionals
              (config.nx.global.deploymentMode == "server" || config.nx.global.deploymentMode == "managed")
              [
                {
                  service = "init.scope";
                  tag = "systemd";
                  string = "Reached target Multi-User System\\.";
                  ignoreRateLimiting = true;
                  mapping = {
                    label = "System";
                    title = "Boot Complete";
                    icon = "dialog-information";
                  };
                }
              ];

          allHighlightPatterns =
            map (p: (p // { pattern_type = "highlight"; }) // { mapping = resolveMapping (p.mapping or null); })
              (
                lib.concatMap expandPattern (
                  baseHighlightPatterns
                  ++ serverManagedHighlightPatterns
                  ++ (map (
                    s:
                    mkPattern {
                      string = s;
                      all = true;
                    }
                  ) baseStringsToHighlight)
                  ++ (map (s: mkPattern { string = s; }) baseSystemStringsToHighlight)
                  ++ (map (
                    s:
                    mkPattern {
                      string = s;
                      kernel = true;
                    }
                  ) baseKernelStringsToHighlight)
                  ++ (map (
                    s:
                    mkPattern {
                      string = s;
                      user = true;
                    }
                  ) baseUserStringsToHighlight)
                  ++ (map (
                    t:
                    mkPattern {
                      tag = t;
                      all = true;
                    }
                  ) baseTagsToHighlight)
                  ++ opts.highlightPatterns
                )
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
                url = hcUrl;
                urlTitle = hcUrlTitle;
              }
            else
              [ ];

          resolveIconField =
            icon:
            if icon == null then
              null
            else if lib.hasPrefix "/" icon then
              icon
            else
              helpers.icons.getIcon config icon;

          resolveMapping =
            mapping:
            if mapping == null then
              null
            else
              mapping
              // {
                icon = resolveIconField (mapping.icon or null);
                infoIcon = resolveIconField (mapping.infoIcon or null);
                warnIcon = resolveIconField (mapping.warnIcon or null);
                failedIcon = resolveIconField (mapping.failedIcon or null);
                emergIcon = resolveIconField (mapping.emergIcon or null);
              };

          allTagMappings = lib.mapAttrs (_: resolveMapping) (baseTagMappings // opts.tagMappings);

          watcherConfigJson = pkgs.writeText "journal-watcher-config.json" (
            builtins.toJSON {
              state_dir = stateDir;
              rate_limit_state_dir = rateLimitStateDir;
              cursor_file = cursorFile;
              message_hashes_file = messageHashesFile;
              rate_limit_per_hour = opts.pushoverRateLimit;
              rate_limit_per_hour_unknown = opts.pushoverRateLimitUnknown;
              highlight_rate_limit_per_hour = opts.highlightRateLimit;
              message_rate_limit_minutes = opts.sameMessageRateLimitMinutes;
              rebuild_window_timeout_seconds = opts.rebuildWindowTimeoutSeconds;
              user_notify_enabled = self.isModuleEnabled "notifications.user-notify";
              pushover_enabled = self.isModuleEnabled "notifications.pushover" && pushover.script != null;
              debug_enabled = opts.debug;
              dev_enabled = false;
              stats_enabled = true;
              ignore_user_services_for_pushover =
                opts.ignoreUserServicesForPushover
                && !(
                  opts.forceEnableUserServicesForPushoverOnHeadless
                  && !config.nx.linux.notifications."user-notify".enable
                  && (config.nx.global.deploymentMode == "managed" || config.nx.global.deploymentMode == "server")
                );
              main_user_uid = config.users.users.${self.host.mainUser.username}.uid;
              main_user_username = self.host.mainUser.username;
              journalctl_bin = "${pkgs.systemd}/bin/journalctl";
              logger_bin = "${pkgs.util-linux}/bin/logger";
              pushover_cmd = pushoverCmd;
              icon_map_system = {
                emerg = helpers.icons.getIcon config "dialog-error";
                failed = helpers.icons.searchIcon config "computer-fail|dialog-error";
                warn = helpers.icons.getIcon config "dialog-warning";
                info = helpers.icons.getIcon config "dialog-information";
              };
              icon_map_user = {
                emerg = helpers.icons.getIcon config "dialog-error";
                failed = helpers.icons.searchIcon config "computer-fail|dialog-error";
                warn = helpers.icons.getIcon config "dialog-warning";
                info = helpers.icons.searchIcon config "avatar-default|dialog-information";
              };
              ignore_patterns = allIgnorePatterns;
              highlight_patterns = allHighlightPatterns;
              tag_mappings = allTagMappings;
            }
          );

          monitorScript = self.file "monitor.py";

          patchConfigScript = pkgs.writeText "journal-watcher-patch-config.py" ''
            import json, os, sys
            source, tmpdir = sys.argv[1], sys.argv[2]
            if not os.path.isdir(tmpdir):
                sys.exit(f"error: tmpdir does not exist or is not a directory: {tmpdir}")
            if not os.path.realpath(tmpdir).startswith("/tmp/"):
                sys.exit(f"error: tmpdir is not under /tmp: {tmpdir}")
            state_dir = tmpdir + "/state"
            with open(source) as f:
                cfg = json.load(f)
            cfg.update({
                "state_dir": state_dir,
                "rate_limit_state_dir": state_dir + "/rate-limits",
                "cursor_file": state_dir + "/cursor",
                "message_hashes_file": state_dir + "/hashes",
                "debug_enabled": True,
                "dev_enabled": True,
                "user_notify_enabled": False,
                "pushover_enabled": False,
                "stats_enabled": False,
            })
            os.makedirs(state_dir, exist_ok=True)
            out = tmpdir + "/config.json"
            with open(out, "w") as f:
                json.dump(cfg, f)
            print(out)
          '';

          testScript = pkgs.writeShellScriptBin "nx-journal-watcher-event-log" ''
            tmpdir=$(mktemp -d)
            trap 'rm -rf "$tmpdir"' EXIT
            config=$(${pkgs.python3}/bin/python3 ${patchConfigScript} ${watcherConfigJson} "$tmpdir")
            ${pkgs.python3}/bin/python3 ${monitorScript} "$config"
          '';

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
                  for field in ("string", "extract"):
                    s = pat.get(field)
                    if s is not None:
                      try:
                        re.compile(s)
                      except re.error as e:
                        errors.append(f"  [{label}] {field}: {fmt_pat(pat)}: {e}")
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
            validatePatterns "ignorePatterns" (baseIgnorePatterns ++ opts.ignorePatterns)
            ++ validatePatterns "highlightPatterns" (
              baseHighlightPatterns ++ serverManagedHighlightPatterns ++ opts.highlightPatterns
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

          systemd.services.nx-shutdown-notify =
            lib.mkIf
              (config.nx.global.deploymentMode == "server" || config.nx.global.deploymentMode == "managed")
              {
                description = "NX Shutdown Notification";
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = "${pkgs.coreutils}/bin/true";
                  ExecStop = "${pkgs.writeShellScript "nx-shutdown-notify-stop" ''
                    set +e
                    mode=""
                    if ${pkgs.systemd}/bin/systemctl list-jobs 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "reboot.target.*start"; then
                      mode="reboot"
                    elif ${pkgs.systemd}/bin/systemctl list-jobs 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qE "(poweroff|halt).target.*start"; then
                      mode="poweroff"
                    elif [ -f /run/systemd/shutdown/scheduled ]; then
                      mode=$(${pkgs.gnugrep}/bin/grep "^MODE=" /run/systemd/shutdown/scheduled | ${pkgs.coreutils}/bin/cut -d= -f2 | ${pkgs.coreutils}/bin/tr -d "[:space:]")
                    fi
                    case "$mode" in
                      reboot)
                        ${pushover.send {
                          title = "System";
                          message = "System is rebooting";
                          type = "info";
                        }}
                        ;;
                      poweroff|halt|kexec)
                        ${pushover.send {
                          title = "System";
                          message = "System is powering off";
                          type = "warn";
                        }}
                        ;;
                      *)
                        ${pushover.send {
                          title = "System";
                          message = "System is going down";
                          type = "warn";
                        }}
                        ;;
                    esac
                    exit 0
                  ''}";
                  NoNewPrivileges = true;
                };
              };

          system.extraDependencies = [ regexValidation ];

          environment.systemPackages = [ testScript ];

          environment.persistence."${self.persist}" = {
            directories = [
              "/var/lib/nx-journal-watcher"
            ];
          };
        };

      ifEnabled.linux.server.healthchecks = {
        enabled = config: {
          nx.linux.server.healthchecks.requireServicesUp = [ "nx-journal-watcher.service" ];
        };
      };
    };
}
