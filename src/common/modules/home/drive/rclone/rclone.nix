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
  name = "rclone";
  group = "drive";
  input = "common";
  namespace = "home";

  settings = {
    enableServices = false;
    debounceSeconds = 5;
    sftpCheckers = 6;
    remotes = { };
  };

  configuration =
    context@{ config, options, ... }:
    let
      hasRemotes = self.settings.remotes != { };
      remoteNames = lib.attrNames self.settings.remotes;
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      luksDataDriveEnabled = self.isLinux && self.linux.isModuleEnabled "storage.luks-data-drive";

      iconThemeString = self.theme.icons.primary;
      iconThemePackage = lib.getAttr (lib.head (lib.splitString "/" iconThemeString)) pkgs;
      iconThemeName = lib.head (lib.tail (lib.splitString "/" iconThemeString));
      iconThemeBasePath = "${iconThemePackage}/share/icons/${iconThemeName}";

      remoteConfigs = lib.mapAttrs (name: cfg: {
        config = {
          type = cfg.type or "webdav";
        }
        // lib.optionalAttrs (cfg ? url) { url = cfg.url; }
        // lib.optionalAttrs (cfg ? host) { host = cfg.host; }
        // lib.optionalAttrs (cfg ? vendor) { vendor = cfg.vendor; }
        // (cfg.extraConfig or { });

        secrets = {
          user = config.sops.secrets."rclone-${name}-user".path;
          pass = config.sops.secrets."rclone-${name}-pass".path;
        };
      }) self.settings.remotes;

      remoteSecrets = lib.foldl' (
        acc: name:
        acc
        // {
          "rclone-${name}-user" = {
            format = "binary";
            sopsFile = self.config.secretsPath "rclone-${name}-user";
            mode = "0400";
          };
          "rclone-${name}-pass" = {
            format = "binary";
            sopsFile = self.config.secretsPath "rclone-${name}-pass";
            mode = "0400";
          };
        }
      ) { } remoteNames;

      rcloneConfigPath = "${config.home.homeDirectory}/.config/rclone/rclone.conf";

      getEventServiceName = name: "rclone-event-sync-${name}";
      getLockfile = name: "\${XDG_RUNTIME_DIR}/rclone-sync-${name}.lock";
      getTimestampFile = name: "\${XDG_RUNTIME_DIR}/rclone-boot-${name}.timestamp";

      bisyncCommonFlags = [
        "--resilient"
        "--compare"
        "size,modtime"
        "--conflict-resolve"
        "newer"
        "--check-sync=false"
        "--create-empty-src-dirs"
        "--links"
      ];

      getBisyncFlags =
        {
          cfg,
          resync ? false,
        }:
        let
          checkersFlag =
            if (cfg.type or "webdav") == "sftp" then
              [ "--checkers=${toString self.settings.sftpCheckers}" ]
            else
              [ ];
          resyncFlags =
            if resync then
              [
                "--resync"
                "--resync-mode=newer"
              ]
            else
              [
                "--recover"
                "--fast-list"
                "--force"
              ];
        in
        resyncFlags ++ bisyncCommonFlags ++ checkersFlag ++ [ "--verbose" ];

      getBisyncFlagsStr = args: lib.concatStringsSep " " (getBisyncFlags args);

      getBisyncCommand =
        {
          remotePath,
          localPath,
          cfg,
        }:
        let
          recoverFlags = getBisyncFlagsStr {
            inherit cfg;
            resync = false;
          };
          resyncFlags = getBisyncFlagsStr {
            inherit cfg;
            resync = true;
          };
        in
        ''
          echo "Running: rclone bisync \"${remotePath}\" \"${localPath}\" ${recoverFlags}"
          if ! ${pkgs.rclone}/bin/rclone bisync "${remotePath}" "${localPath}" ${recoverFlags}; then
            echo "Recovery failed, performing full resync..."
            echo "Running: rclone bisync \"${remotePath}\" \"${localPath}\" ${resyncFlags}"
            ${pkgs.rclone}/bin/rclone bisync "${remotePath}" "${localPath}" ${resyncFlags}
          fi
        '';

      getLockAcquisition =
        {
          name,
          wait ? true,
          notifyWait ? false,
        }:
        let
          lockfile = getLockfile name;
        in
        ''
          LOCKFILE="${lockfile}"
          exec {LOCK_FD}>"$LOCKFILE"
          echo "Acquiring sync lock for ${name}..."
        ''
        + (
          if wait then
            (
              if notifyWait then
                ''
                  if ! ${pkgs.util-linux}/bin/flock --nonblock --exclusive "$LOCK_FD"; then
                    echo "Remote '${name}' is currently syncing. Waiting..."
                    ${pkgs.util-linux}/bin/flock --exclusive "$LOCK_FD"
                  fi
                ''
              else
                ''
                  ${pkgs.util-linux}/bin/flock --exclusive "$LOCK_FD"
                ''
            )
          else
            ''
              if ! ${pkgs.util-linux}/bin/flock --nonblock --exclusive "$LOCK_FD"; then
                echo "Remote '${name}' is currently syncing. Please wait."
                exit 1
              fi
            ''
        )
        + ''
          echo "Lock acquired"
          trap '${pkgs.util-linux}/bin/flock --unlock "$LOCK_FD"' EXIT INT TERM
        '';

      sanityCheckSecrets =
        name:
        let
          userSecretPath = config.sops.secrets."rclone-${name}-user".path;
          passSecretPath = config.sops.secrets."rclone-${name}-pass".path;
        in
        ''
          if [[ ! -r "${userSecretPath}" ]]; then
            echo "ERROR: Secret file not readable for remote '${name}': ${userSecretPath}"
            exit 1
          fi
          if [[ ! -r "${passSecretPath}" ]]; then
            echo "ERROR: Secret file not readable for remote '${name}': ${passSecretPath}"
            exit 1
          fi
        '';

      sanityCheckConfig = ''
        if [[ ! -r "${rcloneConfigPath}" ]]; then
          echo "ERROR: Rclone config not found or not readable: ${rcloneConfigPath}"
          exit 1
        fi
      '';

      sanityChecksFor = name: ''
        ${sanityCheckConfig}
        ${sanityCheckSecrets name}
      '';

      sanityChecksAll = ''
        ${sanityCheckConfig}
        ${lib.concatMapStringsSep "\n" sanityCheckSecrets remoteNames}
      '';

      bisyncCacheDir = "${config.home.homeDirectory}/.cache/rclone/bisync";

      getBisyncLockPath =
        { name, cfg }:
        let
          localPath = getLocalPath cfg;
          localPart =
            if lib.hasPrefix "/" localPath then
              ".." + builtins.replaceStrings [ "/" ] [ "_" ] (lib.removePrefix "/" localPath)
            else
              builtins.replaceStrings [ "/" ] [ "_" ] localPath;
        in
        "${bisyncCacheDir}/${name}_${localPart}.lck";

      clearBisyncLock =
        { name, cfg }:
        let
          lockPath = getBisyncLockPath { inherit name cfg; };
        in
        ''
          if [[ -f "${lockPath}" ]]; then
            echo "Removing stale bisync lockfile: ${lockPath}"
            ${pkgs.coreutils}/bin/rm -f "${lockPath}"
          fi
        '';

      localPaths = lib.filter (p: !(lib.hasPrefix "/" p)) (
        lib.mapAttrsToList (_: cfg: cfg.localPath) self.settings.remotes
      );

      getLocalPath =
        cfg:
        if lib.hasPrefix "/" cfg.localPath then
          cfg.localPath
        else
          "${config.home.homeDirectory}/${cfg.localPath}";

      getRemotePath = name: cfg: "${name}:${cfg.remotePath or "/"}";

      getPingHost =
        cfg:
        if (cfg ? host) then
          cfg.host
        else
          let
            url = cfg.url or "";
            match = builtins.match "^[^:]+://([^/:]+).*" url;
          in
          if match != null then builtins.head match else "";

      getConnectivityCheck =
        cfg:
        let
          pingHost = getPingHost cfg;
        in
        lib.optionalString (pingHost != "") ''
          for i in {1..5}; do
            if ${pkgs.iputils}/bin/ping -c 1 -W 5 "${pingHost}" >/dev/null 2>&1; then
              break
            fi
            if [[ $i -eq 5 ]]; then
              echo "Cannot reach ${pingHost}, skipping sync"
              exit 1
            fi
            ${pkgs.coreutils}/bin/sleep $((i * 2))
          done
        '';

      eventWatcherScript =
        name:
        let
          cfg = self.settings.remotes.${name};
          localPath = getLocalPath cfg;
          remotePath = getRemotePath name cfg;
          pingHost = getPingHost cfg;
          userSecretPath = config.sops.secrets."rclone-${name}-user".path;
          passSecretPath = config.sops.secrets."rclone-${name}-pass".path;
          extraFlagsNix =
            if (cfg.type or "webdav") == "sftp" then
              ''["--checkers=${toString self.settings.sftpCheckers}"]''
            else
              "[]";
        in
        ''
          #!${pkgs.python3}/bin/python3
          import subprocess
          import sys
          import os
          import fcntl
          import tempfile
          import time
          from threading import Timer, Lock, Event

          LOCAL = "${localPath}"
          REMOTE = "${remotePath}"
          REMOTE_NAME = "${name}"
          LOCKFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "rclone-sync-${name}.lock")
          TIMESTAMP_FILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "rclone-sync-${name}.timestamp")
          DEBOUNCE = ${toString self.settings.debounceSeconds}
          RCLONE = "${pkgs.rclone}/bin/rclone"
          INOTIFYWAIT = "${pkgs.inotify-tools}/bin/inotifywait"
          LOGGER = "${pkgs.util-linux}/bin/logger"
          PING = "${pkgs.iputils}/bin/ping"
          EXTRA_FLAGS = ${extraFlagsNix}

          RCLONE_CONFIG = "${rcloneConfigPath}"
          USER_SECRET = "${userSecretPath}"
          PASS_SECRET = "${passSecretPath}"
          PING_HOST = "${pingHost}"

          IGNORED_SUFFIXES = ("~", ".tmp", ".partial", ".swp", ".swo", ".un~", ".socket", ".sock")
          IGNORED_FILES = (".DS_Store", "Thumbs.db", "ehthumbs.db", "Desktop.ini")
          IGNORED_PREFIXES = ("._",)

          BISYNC_RECOVER_FLAGS = ${
            builtins.toJSON (getBisyncFlags {
              inherit cfg;
              resync = false;
            })
          }
          BISYNC_RESYNC_FLAGS = ${
            builtins.toJSON (getBisyncFlags {
              inherit cfg;
              resync = true;
            })
          }
          BISYNC_LOCKFILE = "${getBisyncLockPath { inherit name cfg; }}"


          def clear_bisync_lock():
              if os.path.exists(BISYNC_LOCKFILE):
                  log(f"Removing stale bisync lockfile: {BISYNC_LOCKFILE}")
                  os.remove(BISYNC_LOCKFILE)


          LOG_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "rclone", "event-sync")
          LOG_FILE = os.path.join(LOG_DIR, f"{REMOTE_NAME}.log")
          PROCESSING_FILE = os.path.join(LOG_DIR, f"{REMOTE_NAME}.processing")

          timer = None
          timer_lock = Lock()
          file_lock = Lock()


          def log(message):
              print(message, flush=True)


          def notify(title, message, icon, error=False):
              priority = "user.err" if error else "user.info"
              subprocess.run([LOGGER, "-p", priority, "-t", "nx-user-notify", f"{title}|{icon}: {message}"])


          def ensure_log_dir():
              os.makedirs(LOG_DIR, exist_ok=True)


          def append_event(event_type, relpath):
              with file_lock:
                  ensure_log_dir()
                  with open(LOG_FILE, "a") as f:
                      f.write(f"{event_type}|{relpath}\n")


          def read_log_file(filepath):
              changes = set()
              deletes = set()
              mkdirs = set()
              populates = set()
              purges = set()
              if not os.path.exists(filepath):
                  return changes, deletes, mkdirs, populates, purges
              with open(filepath, "r") as f:
                  for line in f:
                      line = line.strip()
                      if not line or "|" not in line:
                          continue
                      event_type, relpath = line.split("|", 1)
                      if event_type == "C":
                          changes.add(relpath)
                          deletes.discard(relpath)
                          mkdirs.discard(relpath)
                      elif event_type == "D":
                          deletes.add(relpath)
                          changes.discard(relpath)
                          mkdirs.discard(relpath)
                      elif event_type == "M":
                          mkdirs.add(relpath)
                          deletes.discard(relpath)
                          purges.discard(relpath)
                      elif event_type == "P":
                          populates.add(relpath)
                          purges.discard(relpath)
                      elif event_type == "R":
                          purges.add(relpath)
                          populates.discard(relpath)
                          mkdirs.discard(relpath)
              return changes, deletes, mkdirs, populates, purges


          def take_pending():
              with file_lock:
                  if os.path.exists(PROCESSING_FILE):
                      changes, deletes, mkdirs, populates, purges = read_log_file(PROCESSING_FILE)
                      if os.path.exists(LOG_FILE):
                          new_changes, new_deletes, new_mkdirs, new_populates, new_purges = read_log_file(LOG_FILE)
                          for relpath in new_changes:
                              changes.add(relpath)
                              deletes.discard(relpath)
                              mkdirs.discard(relpath)
                          for relpath in new_deletes:
                              deletes.add(relpath)
                              changes.discard(relpath)
                              mkdirs.discard(relpath)
                          for relpath in new_mkdirs:
                              mkdirs.add(relpath)
                              deletes.discard(relpath)
                              purges.discard(relpath)
                          for relpath in new_populates:
                              populates.add(relpath)
                              purges.discard(relpath)
                          for relpath in new_purges:
                              purges.add(relpath)
                              populates.discard(relpath)
                              mkdirs.discard(relpath)
                          os.remove(LOG_FILE)
                      return changes, deletes, mkdirs, populates, purges

                  if not os.path.exists(LOG_FILE):
                      return set(), set(), set(), set(), set()

                  os.rename(LOG_FILE, PROCESSING_FILE)
                  return read_log_file(PROCESSING_FILE)


          def commit_pending():
              with file_lock:
                  if os.path.exists(PROCESSING_FILE):
                      os.remove(PROCESSING_FILE)


          def restore_pending(changes, deletes, mkdirs, populates, purges):
              with file_lock:
                  ensure_log_dir()
                  existing_changes, existing_deletes, existing_mkdirs, existing_populates, existing_purges = read_log_file(LOG_FILE)
                  for relpath in existing_changes:
                      changes.add(relpath)
                      deletes.discard(relpath)
                      mkdirs.discard(relpath)
                  for relpath in existing_deletes:
                      deletes.add(relpath)
                      changes.discard(relpath)
                      mkdirs.discard(relpath)
                  for relpath in existing_mkdirs:
                      mkdirs.add(relpath)
                      deletes.discard(relpath)
                      purges.discard(relpath)
                  for relpath in existing_populates:
                      populates.add(relpath)
                      purges.discard(relpath)
                  for relpath in existing_purges:
                      purges.add(relpath)
                      populates.discard(relpath)
                      mkdirs.discard(relpath)

                  with open(LOG_FILE, "w") as f:
                      for relpath in changes:
                          f.write(f"C|{relpath}\n")
                      for relpath in deletes:
                          f.write(f"D|{relpath}\n")
                      for relpath in mkdirs:
                          f.write(f"M|{relpath}\n")
                      for relpath in populates:
                          f.write(f"P|{relpath}\n")
                      for relpath in purges:
                          f.write(f"R|{relpath}\n")

                  if os.path.exists(PROCESSING_FILE):
                      os.remove(PROCESSING_FILE)


          def flush():
              global timer

              with timer_lock:
                  timer = None

              changes, deletes, mkdirs, populates, purges = take_pending()

              if not changes and not deletes and not mkdirs and not populates and not purges:
                  return

              if not check_connectivity():
                  log("No connectivity - rescheduling flush")
                  restore_pending(changes, deletes, mkdirs, populates, purges)
                  schedule_flush()
                  return

              lock_fd = None
              try:
                  lock_fd = open(LOCKFILE, "w")
                  fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
              except (IOError, BlockingIOError):
                  log("Sync locked - rescheduling")
                  if lock_fd:
                      lock_fd.close()
                  restore_pending(changes, deletes, mkdirs, populates, purges)
                  schedule_flush()
                  return

              synced_count = 0
              deleted_count = 0
              mkdir_count = 0
              populate_count = 0
              purge_count = 0
              failed_changes = set()
              failed_deletes = set()
              failed_mkdirs = set()
              failed_populates = set()
              failed_purges = set()
              progress_notified = Event()

              def notify_progress():
                  progress_notified.set()
                  notify(f"Rclone ({REMOTE_NAME})", "Sync in progress...", "emblem-synchronizing")

              progress_timer = Timer(10, notify_progress)
              progress_timer.start()

              try:
                  actual_changes = {f for f in changes if f and os.path.exists(os.path.join(LOCAL, f))}
                  actual_deletes = {f for f in deletes if f and not os.path.exists(os.path.join(LOCAL, f))}
                  actual_mkdirs = {d for d in mkdirs if d and os.path.isdir(os.path.join(LOCAL, d))}
                  actual_populates = {d for d in populates if d and os.path.isdir(os.path.join(LOCAL, d))}
                  actual_purges = {d for d in purges if d and not os.path.exists(os.path.join(LOCAL, d))}

                  def find_root_dirs(dirs):
                      roots = set()
                      for d in dirs:
                          is_root = True
                          parent = os.path.dirname(d)
                          while parent:
                              if parent in dirs:
                                  is_root = False
                                  break
                              parent = os.path.dirname(parent)
                          if is_root:
                              roots.add(d)
                      return roots

                  def is_under_any(path, dirs):
                      for d in dirs:
                          if path.startswith(d + os.sep) or path == d:
                              return True
                      return False

                  root_mkdirs = find_root_dirs(actual_mkdirs)
                  tree_copy_dirs = set()
                  for d in root_mkdirs:
                      local_dir = os.path.join(LOCAL, d)
                      try:
                          if os.listdir(local_dir):
                              tree_copy_dirs.add(d)
                      except OSError:
                          pass

                  tree_copy_dirs.update(actual_populates)

                  if tree_copy_dirs:
                      actual_changes = {f for f in actual_changes if not is_under_any(f, tree_copy_dirs)}

                  root_purges = find_root_dirs(actual_purges)
                  if root_purges:
                      actual_deletes = {f for f in actual_deletes if not is_under_any(f, root_purges)}

                  if root_purges:
                      log(f"Purging {len(root_purges)} directory tree(s) from remote:")
                      for d in sorted(root_purges):
                          log(f"  purge: {d}")
                          result = subprocess.run(
                              [RCLONE, "purge", f"{REMOTE}/{d}"],
                              capture_output=True, text=True
                          )
                          if result.returncode != 0 and "not found" not in result.stderr.lower() and "directory not found" not in result.stderr.lower():
                              log(f"  purge failed: {result.stderr}")
                              failed_purges.add(d)
                          else:
                              purge_count += 1

                  if actual_changes:
                      log(f"Uploading {len(actual_changes)} file(s):")
                      for f in sorted(actual_changes):
                          log(f"  + {f}")
                      with tempfile.NamedTemporaryFile(mode="w", suffix=".txt") as f:
                          f.write("\n".join(actual_changes))
                          f.flush()
                          result = subprocess.run(
                              [RCLONE, "copy", "--files-from", f.name, LOCAL, REMOTE, "--update", "--links", "-v"] + EXTRA_FLAGS,
                              capture_output=True, text=True
                          )
                          if result.returncode != 0:
                              log(f"Copy failed: {result.stderr}")
                              failed_changes = actual_changes
                          else:
                              synced_count = sum(1 for line in result.stderr.split('\n') if ': Copied' in line)
                              if synced_count < len(actual_changes):
                                  log(f"Actually uploaded {synced_count} file(s) ({len(actual_changes) - synced_count} skipped)")

                  if actual_deletes:
                      log(f"Deleting {len(actual_deletes)} file(s) from remote:")
                      for f in sorted(actual_deletes):
                          log(f"  - {f}")
                      with tempfile.NamedTemporaryFile(mode="w", suffix=".txt") as f:
                          f.write("\n".join(actual_deletes))
                          f.flush()
                          result = subprocess.run(
                              [RCLONE, "delete", "--files-from", f.name, REMOTE, "-v"],
                              capture_output=True, text=True
                          )
                          if result.returncode != 0:
                              log(f"Delete failed: {result.stderr}")
                              failed_deletes = actual_deletes
                          else:
                              deleted_count = sum(1 for line in result.stderr.split('\n') if ': Deleted' in line)
                              all_paths = set()
                              for filepath in actual_deletes:
                                  parent = os.path.dirname(filepath)
                                  while parent:
                                      all_paths.add(parent)
                                      parent = os.path.dirname(parent)
                              log(f"Checking {len(all_paths)} paths for directory cleanup")
                              root_deleted = set()
                              for path in all_paths:
                                  if os.path.exists(os.path.join(LOCAL, path)):
                                      continue
                                  parent = os.path.dirname(path)
                                  is_root = True
                                  while parent:
                                      if parent in all_paths and not os.path.exists(os.path.join(LOCAL, parent)):
                                          is_root = False
                                          break
                                      parent = os.path.dirname(parent)
                                  if is_root:
                                      root_deleted.add(path)
                              if root_deleted:
                                  log(f"Cleaning up {len(root_deleted)} root directory path(s):")
                              for path in sorted(root_deleted):
                                  log(f"  rmdirs: {REMOTE}/{path}")
                                  result = subprocess.run(
                                      [RCLONE, "rmdirs", f"{REMOTE}/{path}"],
                                      capture_output=True, text=True
                                  )
                                  if result.returncode != 0 and "not found" not in result.stderr.lower():
                                      log(f"  rmdirs failed: {result.stderr}")

                  empty_mkdirs = root_mkdirs - tree_copy_dirs
                  if empty_mkdirs:
                      log(f"Creating {len(empty_mkdirs)} empty directory(ies):")
                      for d in sorted(empty_mkdirs):
                          log(f"  mkdir: {d}")
                          result = subprocess.run(
                              [RCLONE, "mkdir", f"{REMOTE}/{d}"],
                              capture_output=True, text=True
                          )
                          if result.returncode != 0 and "already exists" not in result.stderr.lower():
                              log(f"  mkdir failed: {result.stderr}")
                              failed_mkdirs.add(d)
                          else:
                              mkdir_count += 1

                  if tree_copy_dirs:
                      log(f"Copying {len(tree_copy_dirs)} directory tree(s) to remote:")
                      for d in sorted(tree_copy_dirs):
                          log(f"  copy tree: {d}")
                          result = subprocess.run(
                              [RCLONE, "copy", os.path.join(LOCAL, d), f"{REMOTE}/{d}", "--links", "-v"] + EXTRA_FLAGS,
                              capture_output=True, text=True
                          )
                          if result.returncode != 0:
                              log(f"  copy tree failed: {result.stderr}")
                              failed_populates.add(d)
                          else:
                              populate_count += 1

                  if failed_changes or failed_deletes or failed_mkdirs or failed_populates or failed_purges:
                      restore_pending(failed_changes, failed_deletes, failed_mkdirs, failed_populates, failed_purges)
                      notify(f"Rclone ({REMOTE_NAME})", "Sync failed", "dialog-error", error=True)
                  else:
                      commit_pending()
                      if synced_count > 0 or deleted_count > 0 or populate_count > 0 or purge_count > 0:
                          parts = []
                          if synced_count > 0:
                              parts.append(f"uploaded {synced_count} files")
                          if deleted_count > 0:
                              parts.append(f"deleted {deleted_count} files")
                          if populate_count > 0:
                              parts.append(f"copied {populate_count} dirs")
                          if purge_count > 0:
                              parts.append(f"deleted {purge_count} dirs")
                          msg = ", ".join(parts).capitalize()
                          notify(f"Rclone ({REMOTE_NAME})", msg, "emblem-synchronizing")
                      elif mkdir_count > 0:
                          notify(f"Rclone ({REMOTE_NAME})", "Sync completed", "emblem-synchronizing")
                      elif progress_notified.is_set():
                          notify(f"Rclone ({REMOTE_NAME})", "Sync completed (already up to date)", "emblem-synchronizing")
              finally:
                  progress_timer.cancel()
                  fcntl.flock(lock_fd, fcntl.LOCK_UN)
                  lock_fd.close()


          def schedule_flush():
              global timer
              with timer_lock:
                  if timer is not None:
                      timer.cancel()
                  timer = Timer(DEBOUNCE, flush)
                  timer.start()


          overflow_timer = None
          overflow_lock = Lock()


          def overflow_bisync():
              global overflow_timer
              with overflow_lock:
                  overflow_timer = None

              if not check_connectivity():
                  log("No connectivity - rescheduling overflow bisync")
                  schedule_overflow_bisync()
                  return

              log("Running full bisync due to overflow")
              lock_fd = None
              try:
                  lock_fd = open(LOCKFILE, "w")
                  fcntl.flock(lock_fd, fcntl.LOCK_EX)
              except Exception as e:
                  log(f"Failed to acquire lock for overflow bisync: {e}")
                  return

              try:
                  clear_bisync_lock()
                  cmd = [RCLONE, "bisync", REMOTE, LOCAL] + BISYNC_RECOVER_FLAGS
                  log(f"Running: {' '.join(cmd)}")
                  result = subprocess.run(cmd)
                  if result.returncode != 0:
                      log("Overflow bisync recover failed, trying resync")
                      clear_bisync_lock()
                      cmd = [RCLONE, "bisync", REMOTE, LOCAL] + BISYNC_RESYNC_FLAGS
                      log(f"Running: {' '.join(cmd)}")
                      result = subprocess.run(cmd)
                  if result.returncode != 0:
                      log("Overflow bisync failed")
                      notify(f"Rclone ({REMOTE_NAME})", "Overflow sync failed", "dialog-error", error=True)
                  else:
                      open(TIMESTAMP_FILE, 'w').close()
                      notify(f"Rclone ({REMOTE_NAME})", "Overflow sync completed", "emblem-ok-symbolic")
              finally:
                  fcntl.flock(lock_fd, fcntl.LOCK_UN)
                  lock_fd.close()


          def schedule_overflow_bisync():
              global overflow_timer
              with overflow_lock:
                  if overflow_timer is not None:
                      return
                  overflow_timer = Timer(DEBOUNCE, overflow_bisync)
                  overflow_timer.start()


          def handle_event(event, relpath):
              if not relpath or relpath == ".":
                  return
              if ".." in relpath.split(os.sep) or relpath.startswith("/"):
                  log(f"WARNING: Ignoring potentially unsafe path: {repr(relpath)}")
                  return
              if "\n" in relpath or "\r" in relpath:
                  log(f"WARNING: Ignoring file with newline/carriage-return in path: {repr(relpath)}")
                  return
              event_parts = event.split(",")
              event_name = event_parts[0]
              is_dir = "ISDIR" in event_parts
              if is_dir and event_name in ("DELETE", "MOVED_FROM"):
                  event_type = "R"
              elif is_dir and event_name == "CREATE":
                  event_type = "M"
              elif is_dir and event_name == "MOVED_TO":
                  event_type = "P"
              elif event_name in ("DELETE", "MOVED_FROM"):
                  event_type = "D"
              else:
                  event_type = "C"
              append_event(event_type, relpath)
              schedule_flush()


          def should_initial_sync():
              if not os.path.exists(TIMESTAMP_FILE):
                  return True
              age = time.time() - os.path.getmtime(TIMESTAMP_FILE)
              return age > 3600


          def process_pending_log():
              with file_lock:
                  has_pending = os.path.exists(LOG_FILE) or os.path.exists(PROCESSING_FILE)
              if has_pending:
                  log("Found pending events from previous run, scheduling flush")
                  schedule_flush()


          def sanity_check():
              if not os.access(RCLONE_CONFIG, os.R_OK):
                  log(f"ERROR: Rclone config not readable: {RCLONE_CONFIG}")
                  return False
              if not os.access(USER_SECRET, os.R_OK):
                  log(f"ERROR: User secret not readable: {USER_SECRET}")
                  return False
              if not os.access(PASS_SECRET, os.R_OK):
                  log(f"ERROR: Pass secret not readable: {PASS_SECRET}")
                  return False
              return True


          def check_local_directory():
              if not os.path.isdir(LOCAL):
                  log(f"ERROR: Local sync directory does not exist: {LOCAL}")
                  log("Run 'rclone-sync-init' first to initialize the sync.")
                  return False
              return True


          def check_connectivity():
              if not PING_HOST:
                  return True
              for i in range(1, 6):
                  result = subprocess.run(
                      [PING, "-c", "1", "-W", "5", PING_HOST],
                      capture_output=True
                  )
                  if result.returncode == 0:
                      return True
                  if i < 5:
                      time.sleep(i * 2)
              log(f"Cannot reach {PING_HOST} after 5 attempts")
              return False


          def initial_sync():
              process_pending_log()

              if not sanity_check():
                  log("Sanity check failed, exiting")
                  sys.exit(1)

              if not check_local_directory():
                  log("Local directory check failed, exiting")
                  sys.exit(1)

              if not should_initial_sync():
                  log("Sync recent, skipping initial sync")
                  return

              if not check_connectivity():
                  log("No connectivity, skipping initial sync (will sync on first event)")
                  return

              lock_fd = None
              try:
                  lock_fd = open(LOCKFILE, "w")
                  fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
              except (IOError, BlockingIOError):
                  log("Another sync in progress, skipping initial sync")
                  if lock_fd:
                      lock_fd.close()
                  return

              log("Performing initial bisync")
              notify(f"Rclone ({REMOTE_NAME})", "Initial sync starting...", "emblem-synchronizing")
              try:
                  clear_bisync_lock()
                  cmd = [RCLONE, "bisync", REMOTE, LOCAL] + BISYNC_RECOVER_FLAGS
                  log(f"Running: {' '.join(cmd)}")
                  result = subprocess.run(cmd)
                  if result.returncode != 0:
                      log("Bisync recover failed, trying resync")
                      clear_bisync_lock()
                      cmd = [RCLONE, "bisync", REMOTE, LOCAL] + BISYNC_RESYNC_FLAGS
                      log(f"Running: {' '.join(cmd)}")
                      result = subprocess.run(cmd)
                  if result.returncode != 0:
                      log("Initial sync failed")
                      notify(f"Rclone ({REMOTE_NAME})", "Initial sync failed", "dialog-error", error=True)
                  else:
                      open(TIMESTAMP_FILE, 'w').close()
                      notify(f"Rclone ({REMOTE_NAME})", "Initial sync completed", "emblem-ok-symbolic")
              finally:
                  fcntl.flock(lock_fd, fcntl.LOCK_UN)
                  lock_fd.close()


          def get_watch_limit():
              try:
                  with open("/proc/sys/fs/inotify/max_user_watches") as f:
                      return int(f.read().strip())
              except Exception:
                  return None


          def main():
              limit = get_watch_limit()
              log(f"Starting inotifywait (system limit: {limit} watches)")

              proc = subprocess.Popen(
                  [INOTIFYWAIT, "-m", "-r", "--format", "%e|%w%f",
                   "-e", "modify,create,delete,moved_from,moved_to,close_write", LOCAL],
                  stdout=subprocess.PIPE,
                  text=True,
              )

              log("Watching for changes")

              initial_sync()

              try:
                  for line in proc.stdout:
                      line = line.strip()
                      if "Q_OVERFLOW" in line:
                          log("WARNING: inotify queue overflow detected, scheduling full bisync")
                          notify(f"Rclone ({REMOTE_NAME})", "Event overflow, syncing...", "dialog-warning")
                          schedule_overflow_bisync()
                          continue
                      if "|" not in line:
                          continue
                      event, filepath = line.split("|", 1)
                      if not filepath.startswith(LOCAL):
                          continue
                      relpath = os.path.relpath(filepath, LOCAL)
                      basename = os.path.basename(relpath)
                      if basename in IGNORED_FILES:
                          continue
                      if any(basename.endswith(s) for s in IGNORED_SUFFIXES):
                          continue
                      if any(basename.startswith(p) for p in IGNORED_PREFIXES):
                          continue
                      handle_event(event, relpath)
              except KeyboardInterrupt:
                  pass
              finally:
                  with timer_lock:
                      if timer is not None:
                          timer.cancel()
                  proc.terminate()
                  proc.wait()
                  log("Watcher stopped")

              exit_code = proc.returncode
              if exit_code != 0:
                  log(f"inotifywait exited with code {exit_code}")
                  sys.exit(1)


          if __name__ == "__main__":
              main()
        '';

      eventWatcherScriptDrv =
        name: pkgs.writeScript "rclone-event-watcher-${name}" (eventWatcherScript name);

      eventSyncServices = lib.foldl' (
        acc: name:
        acc
        // {
          "rclone-event-sync-${name}" = lib.mkMerge [
            (lib.mkIf luksDataDriveEnabled {
              Unit = {
                After = lib.mkAfter [ "nx-luks-data-drive-ready.service" ];
                Requires = lib.mkAfter [ "nx-luks-data-drive-ready.service" ];
              };
            })
            {
              Unit = {
                Description = "Rclone event-driven sync watcher for ${name}";
                After = [
                  "sops-nix.service"
                  "rclone-config.service"
                ];
              };
              Service = {
                Type = "simple";
                ExecStart = "${eventWatcherScriptDrv name}";
                Restart = "on-failure";
                RestartSec = 30;
                Environment = [
                  "PATH=${lib.makeBinPath [ pkgs.coreutils ]}"
                ];
              };
              Install = lib.mkIf self.settings.enableServices {
                WantedBy = [ "default.target" ];
              };
            }
          ];
        }
      ) { } remoteNames;

      manualBisyncService = {
        "rclone-bisync-manual" = {
          Unit = {
            Description = "Rclone manual bisync for all remotes";
          };
          Service = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "rclone-bisync-manual-exec" ''
              set -euo pipefail

              ${sanityChecksAll}

              SYNC_FAILED=0

              ${lib.concatMapStringsSep "\n" (
                name:
                let
                  cfg = self.settings.remotes.${name};
                  localPath = getLocalPath cfg;
                  remotePath = getRemotePath name cfg;
                  connectivityCheck = getConnectivityCheck cfg;
                  bisyncCmd = getBisyncCommand { inherit remotePath localPath cfg; };
                in
                ''
                  (
                    ${getLockAcquisition {
                      inherit name;
                      notifyWait = true;
                    }}

                    echo "Syncing ${name}..."
                    ${connectivityCheck}

                    ${clearBisyncLock { inherit name cfg; }}

                    ${bisyncCmd}

                    ${pkgs.coreutils}/bin/touch "${getTimestampFile name}"
                  ) || SYNC_FAILED=1
                ''
              ) remoteNames}

              if [[ $SYNC_FAILED -eq 0 ]]; then
                echo "Manual bisync completed successfully."
                ${pkgs.util-linux}/bin/logger -t nx-user-notify "Rclone|emblem-ok-symbolic: Manual sync completed"
              else
                echo "Manual bisync failed for one or more remotes."
                ${pkgs.util-linux}/bin/logger -p user.err -t nx-user-notify "Rclone|dialog-error: Manual sync failed"
                exit 1
              fi
            '';
          };
        };
      };

    in
    lib.mkIf hasRemotes {
      programs.rclone = {
        enable = true;
        remotes = remoteConfigs;
        requiresUnit = "sops-nix.service";
      };

      sops.secrets = remoteSecrets;

      systemd.user.services = eventSyncServices // manualBisyncService;

      home.packages = [
        pkgs.inotify-tools

        (pkgs.writeShellScriptBin "rclone-sync-init" ''
          set -euo pipefail

          echo "WARNING: This will perform a --resync operation which can lead to data loss!"
          echo "This should only be run for initial setup or to recover from sync conflicts."
          echo ""
          read -p "Are you sure you want to continue? [y/N] " -n 1 -r
          echo
          if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
          fi

          ${sanityChecksAll}

          ${lib.concatMapStringsSep "\n" (
            name:
            let
              cfg = self.settings.remotes.${name};
              localPath = getLocalPath cfg;
              remotePath = getRemotePath name cfg;
              bisyncFlags = getBisyncFlagsStr {
                inherit cfg;
                resync = true;
              };
            in
            ''
              (
                ${getLockAcquisition {
                  inherit name;
                  wait = false;
                }}

                echo "Initializing ${name}..."
                ${pkgs.coreutils}/bin/mkdir -p "${localPath}"
                ${clearBisyncLock { inherit name cfg; }}
                ${pkgs.rclone}/bin/rclone bisync "${remotePath}" "${localPath}" ${bisyncFlags}
              )
            ''
          ) remoteNames}

          echo ""
          echo "Initialization complete."
        '')

        (pkgs.writeShellScriptBin "rclone-bisync-manual" ''
          set -euo pipefail

          echo "This will perform a bisync (tries recovery first, falls back to resync)."
          echo "The newer file (by modification time) will be kept when files differ."
          echo ""
          read -p "Are you sure you want to continue? [y/N] " -n 1 -r
          echo
          if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
          fi

          ${pkgs.systemd}/bin/systemctl --user start --no-block rclone-bisync-manual.service
          ${pkgs.systemd}/bin/journalctl --user -f -u rclone-bisync-manual.service || true
        '')
      ]
      ++ (map (
        name:
        let
          cfg = self.settings.remotes.${name};
        in
        pkgs.writeShellScriptBin "rclone-clear-lock-${name}" ''
          set -euo pipefail
          ${clearBisyncLock { inherit name cfg; }}
          echo "Done."
        ''
      ) remoteNames);

      home.persistence."${self.persist}" = {
        directories = [
          ".config/rclone"
          ".cache/rclone"
        ]
        ++ localPaths;
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Shift+E" = {
              action = spawn [
                "${pkgs.bash}/bin/bash"
                "-c"
                ''
                  STATE=$(${pkgs.systemd}/bin/systemctl --user show -p ActiveState --value rclone-bisync-manual.service)
                  if [[ "$STATE" == "activating" ]]; then
                    ${pkgs.util-linux}/bin/logger -t nx-user-notify "Rclone|emblem-synchronizing: Manual sync already running"
                  else
                    ${pkgs.util-linux}/bin/logger -t nx-user-notify "Rclone|emblem-synchronizing: Starting manual sync..."
                    ${pkgs.systemd}/bin/systemctl --user start rclone-bisync-manual.service
                  fi
                ''
              ];
              hotkey-overlay.title = "Apps:Rclone Manual Sync";
            };
          };
        };
      };
    };
}
