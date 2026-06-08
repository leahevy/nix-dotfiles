{ lib, self }:
{
  denyFilesystemDirPathsCommon = {
    "${self.user.home}/.ssh" = "deny";
    "${self.user.home}/.gnupg" = "deny";
    "${self.user.home}/.config/sops-nix/secrets" = "deny";
    "${self.user.home}/.config/sops" = "deny";
  };

  denyFilesystemDirPathsLinux = {
  };

  denyFilesystemDirPathsDarwin = { };

  denyFilesystemFilePathsCommon = { };
  denyFilesystemFilePathsLinux = { };
  denyFilesystemFilePathsDarwin = { };

  askExecpolicyPatternsCommon = [
    [ "rm" ]
    [ "rmdir" ]
    [ "shred" ]
    [ "wipe" ]
    [ "srm" ]
    [ "mv" ]
    [ "cp" ]
    [ "ln" ]
    [ "link" ]
    [ "unlink" ]
    [ "truncate" ]
    [ "fallocate" ]
    [ "dd" ]

    [ "chmod" ]
    [ "chown" ]
    [ "chgrp" ]
    [ "setfacl" ]
    [ "chattr" ]

    [ "useradd" ]
    [ "userdel" ]
    [ "usermod" ]
    [ "groupadd" ]
    [ "groupdel" ]
    [ "groupmod" ]
    [ "passwd" ]
    [ "chpasswd" ]
    [ "chsh" ]
    [ "sudo" ]
    [ "su" ]
    [ "doas" ]
    [ "pkexec" ]

    [ "kill" ]
    [ "killall" ]
    [ "pkill" ]
    [ "xkill" ]

    [ "reboot" ]
    [ "shutdown" ]
    [ "poweroff" ]
    [ "halt" ]
    [ "init" ]
    [ "telinit" ]

    [
      "git"
      "push"
    ]
    [
      "git"
      "reset"
    ]
    [
      "git"
      "clean"
    ]
    [
      "git"
      "checkout"
      "--"
    ]
    [
      "git"
      "checkout"
      "."
    ]
    [
      "git"
      "restore"
      "--staged"
    ]
    [
      "git"
      "restore"
    ]
    [
      "git"
      "branch"
      "-D"
    ]
    [
      "git"
      "branch"
      "-d"
    ]
    [
      "git"
      "rebase"
    ]
    [
      "git"
      "stash"
      "drop"
    ]
    [
      "git"
      "stash"
      "clear"
    ]
    [
      "git"
      "stash"
      "pop"
    ]
    [
      "git"
      "merge"
    ]
    [
      "git"
      "cherry-pick"
    ]
    [
      "git"
      "revert"
    ]
    [
      "git"
      "tag"
      "-d"
    ]
    [
      "git"
      "remote"
    ]
    [
      "git"
      "ls-remote"
    ]
    [
      "git"
      "submodule"
    ]
    [
      "git"
      "am"
    ]
    [
      "git"
      "format-patch"
    ]
    [
      "git"
      "filter-branch"
    ]
    [
      "git"
      "reflog"
      "expire"
    ]
    [
      "git"
      "gc"
    ]
    [
      "git"
      "commit"
    ]
    [
      "git"
      "add"
    ]

    [ "curl" ]
    [ "wget" ]
    [ "ssh" ]
    [ "scp" ]
    [ "rsync" ]
    [ "sftp" ]
    [ "nc" ]
    [ "ncat" ]
    [ "netcat" ]
    [ "socat" ]
    [ "telnet" ]

    [ "sops" ]
    [ "gpg" ]
    [ "age" ]
    [ "openssl" ]
    [ "ssh-keygen" ]
    [ "ssh-add" ]

    [ "tar" ]
    [ "unzip" ]
    [ "zip" ]
    [ "gzip" ]
    [ "gunzip" ]
    [ "bzip2" ]
    [ "xz" ]
    [ "zstd" ]
    [ "7z" ]
    [ "cpio" ]

    [
      "pip"
      "install"
    ]
    [
      "pip"
      "uninstall"
    ]
    [
      "pip3"
      "install"
    ]
    [
      "pip3"
      "uninstall"
    ]
    [
      "npm"
      "install"
    ]
    [
      "npm"
      "uninstall"
    ]
    [
      "npm"
      "run"
    ]
    [ "npx" ]
    [
      "yarn"
      "add"
    ]
    [
      "yarn"
      "remove"
    ]
    [
      "pnpm"
      "add"
    ]
    [
      "pnpm"
      "remove"
    ]
    [
      "cargo"
      "install"
    ]
    [
      "cargo"
      "uninstall"
    ]
    [
      "go"
      "install"
    ]
    [
      "gem"
      "install"
    ]

    [
      "sed"
      "-i"
    ]
    [ "patch" ]
    [ "tee" ]
    [ "xargs" ]
    [ "direnv" ]
    [ "eval" ]
    [ "exec" ]
    [ "source" ]
    [ "." ]
    [ "nohup" ]
    [ "screen" ]
    [ "tmux" ]
    [ "disown" ]

    [ "chroot" ]
    [ "pivot_root" ]
    [ "unshare" ]
    [ "nsenter" ]
    [ "strace" ]
    [ "ltrace" ]
    [ "ptrace" ]
    [ "gdb" ]

    [ "write" ]
    [ "wall" ]
    [ "mesg" ]
    [ "xdg-open" ]
    [ "open" ]
    [ "dbus-send" ]
    [ "gdbus" ]
    [ "qdbus" ]
    [ "notify-send" ]
    [ "dmesg" ]

    [ "sh" ]
    [ "bash" ]
    [ "fish" ]
    [ "zsh" ]
    [ "dash" ]

    [ "python" ]
    [ "python3" ]
    [ "python2" ]
    [ "ruby" ]
    [ "perl" ]
    [ "node" ]
    [ "ts-node" ]
    [ "tsx" ]
    [ "tsc" ]
    [ "deno" ]
    [
      "bun"
      "install"
    ]
    [
      "bun"
      "add"
    ]
    [
      "bun"
      "remove"
    ]
    [
      "bun"
      "run"
    ]
    [ "bunx" ]

    [
      "nix"
      "build"
    ]
    [
      "nix"
      "eval"
    ]
    [
      "nix"
      "develop"
    ]
    [
      "nix"
      "shell"
    ]
    [
      "nix"
      "run"
    ]
    [
      "nix"
      "store"
    ]
    [
      "nix"
      "profile"
    ]
    [
      "nix"
      "copy"
    ]
    [
      "nix"
      "upgrade-nix"
    ]
    [
      "nix"
      "flake"
      "update"
    ]
    [
      "nix"
      "flake"
      "lock"
    ]
    [
      "nix"
      "flake"
      "prefetch"
    ]
    [ "nix-prefetch-url" ]
    [ "nix-prefetch-git" ]
  ];

  askExecpolicyPatternsLinux = [
    [ "fdisk" ]
    [ "gdisk" ]
    [ "sgdisk" ]
    [ "parted" ]
    [ "partprobe" ]
    [ "wipefs" ]
    [ "blkdiscard" ]
    [ "mount" ]
    [ "umount" ]
    [ "losetup" ]
    [ "cryptsetup" ]
    [ "swapon" ]
    [ "swapoff" ]
    [ "fstrim" ]
    [ "e2fsck" ]
    [ "xfs_repair" ]
    [ "btrfs" ]
    [ "zpool" ]
    [ "zfs" ]
    [ "lvremove" ]
    [ "lvcreate" ]
    [ "vgremove" ]
    [ "pvremove" ]
    [ "mdadm" ]

    [
      "systemctl"
      "start"
    ]
    [
      "systemctl"
      "stop"
    ]
    [
      "systemctl"
      "restart"
    ]
    [
      "systemctl"
      "disable"
    ]
    [
      "systemctl"
      "enable"
    ]
    [
      "systemctl"
      "mask"
    ]
    [
      "systemctl"
      "unmask"
    ]
    [
      "systemctl"
      "daemon-reload"
    ]
    [
      "systemctl"
      "set-default"
    ]
    [
      "journalctl"
      "--vacuum"
    ]
    [ "loginctl" ]
    [ "machinectl" ]
    [ "sysctl" ]
    [ "modprobe" ]
    [ "rmmod" ]
    [ "insmod" ]
    [ "depmod" ]
    [ "udevadm" ]

    [ "iptables" ]
    [ "ip6tables" ]
    [ "nft" ]
    [ "ip" ]
    [ "ifconfig" ]
    [ "route" ]
    [ "nmcli" ]
    [ "networkctl" ]
    [ "resolvectl" ]
    [ "hostnamectl" ]
    [ "timedatectl" ]
    [ "localectl" ]
    [ "firewall-cmd" ]
    [ "ufw" ]

    [ "nixos-rebuild" ]
    [ "nix-collect-garbage" ]
    [
      "nix-store"
      "--delete"
    ]
  ];

  askExecpolicyPatternsDarwin = [
    [ "diskutil" ]
    [ "launchctl" ]
    [ "csrutil" ]

    [
      "brew"
      "install"
    ]
    [
      "brew"
      "uninstall"
    ]
    [
      "brew"
      "remove"
    ]
    [
      "brew"
      "upgrade"
    ]
    [
      "brew"
      "update"
    ]
    [
      "brew"
      "tap"
    ]
    [
      "brew"
      "untap"
    ]
    [
      "brew"
      "bundle"
    ]
    [
      "brew"
      "link"
    ]
    [
      "brew"
      "unlink"
    ]
    [
      "brew"
      "cleanup"
    ]
    [
      "brew"
      "pin"
    ]
    [
      "brew"
      "unpin"
    ]
  ];

  askPromptOnlyGlobsCommon = [
    "sh -c *"
    "bash -c *"
    "fish -c *"
    "zsh -c *"
    "dash -c *"
  ];

  askPromptOnlyGlobsLinux = [
    "mkfs*"
    "fsck*"
  ];

  askPromptOnlyGlobsDarwin = [ ];
}
