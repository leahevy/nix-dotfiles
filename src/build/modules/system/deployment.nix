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
  name = "deployment";

  group = "system";
  input = "build";

  enableOnDeploymentModes = [
    "managed"
    "server"
  ];

  module = {
    when = [
      {
        condition =
          config:
          (
            config.nx.profile.host.deploymentMode == "managed"
            || config.nx.profile.host.deploymentMode == "server"
          )
          && config.nx.profile.host.remote.address != null
          && config.nx.profile.host.remote.deploySSHPublicKey != null;

        do = {
          system = config: {
            users.groups.nx-deployment = { };

            users.users.nx-deployment = {
              isSystemUser = true;
              group = "nx-deployment";
              hashedPassword = "*";
              createHome = true;
              home = "/var/lib/nx-deployment";
              shell = pkgs.bashInteractive;
              openssh.authorizedKeys.keys = [ config.nx.profile.host.remote.deploySSHPublicKey ];
            };

            services.openssh.settings.AllowUsers = lib.mkAfter [ "nx-deployment" ];

            security.sudo.extraRules = [
              {
                users = [ "nx-deployment" ];
                commands = [
                  {
                    command = "/run/current-system/sw/bin/nix-env -p /nix/var/nix/profiles/system --set /nix/store/*-nixos-system-${self.host.hostname}-*";
                    options = [ "NOPASSWD" ];
                  }
                  {
                    command = "/run/current-system/sw/bin/env NIXOS_INSTALL_BOOTLOADER=0 systemd-run -E LOCALE_ARCHIVE -E NIXOS_INSTALL_BOOTLOADER --collect --no-ask-password --pipe --quiet --service-type=exec --unit=nixos-rebuild-switch-to-configuration /nix/store/*-nixos-system-${self.host.hostname}-*/bin/switch-to-configuration switch";
                    options = [ "NOPASSWD" ];
                  }
                  {
                    command = "/run/current-system/sw/bin/env NIXOS_INSTALL_BOOTLOADER=0 systemd-run -E LOCALE_ARCHIVE -E NIXOS_INSTALL_BOOTLOADER --collect --no-ask-password --pipe --quiet --service-type=exec --unit=nixos-rebuild-switch-to-configuration /nix/store/*-nixos-system-${self.host.hostname}-*/bin/switch-to-configuration test";
                    options = [ "NOPASSWD" ];
                  }
                  {
                    command = "/run/current-system/sw/bin/env NIXOS_INSTALL_BOOTLOADER=0 systemd-run -E LOCALE_ARCHIVE -E NIXOS_INSTALL_BOOTLOADER --collect --no-ask-password --pipe --quiet --service-type=exec --unit=nixos-rebuild-switch-to-configuration /nix/store/*-nixos-system-${self.host.hostname}-*/bin/switch-to-configuration boot";
                    options = [ "NOPASSWD" ];
                  }
                ];
              }
            ];
          };
        };
      }
      {
        condition =
          config:
          (
            config.nx.profile.host.deploymentMode == "managed"
            || config.nx.profile.host.deploymentMode == "server"
          )
          && config.nx.profile.host.remote.address != null;

        do = {
          system =
            config:
            let
              hasLuks = (config.boot.initrd.luks.devices or { }) != { };
              hostKey = config.nx.profile.host.remote.initrdSSHHostPrivateKey;
              pubKey = config.nx.profile.host.remote.initrdSSHHostPublicKey;
              port = config.nx.profile.host.remote.initrdSSHServicePort;
              installKey = self.variables.isoManagementSSHKey or null;
              authorizedKeys = lib.unique (
                (config.users.users.${config.nx.profile.host.mainUser.username}.openssh.authorizedKeys.keys or [ ])
                ++ lib.optional (installKey != null) (helpers.sshPublicKeyToString installKey.public)
              );
              hostKeyFile = pkgs.writeText "initrd-host-key" (if hostKey != null then hostKey else "");
              initrdShell = pkgs.writeShellScript "initrd-shell" ''
                exec ${pkgs.systemd}/bin/systemd-tty-ask-password-agent --watch
              '';
              keypairCheck =
                pkgs.runCommand "validate-initrd-ssh-keypair"
                  {
                    nativeBuildInputs = [
                      pkgs.openssh
                      pkgs.coreutils
                    ];
                    configuredPubKey = pubKey;
                  }
                  ''
                    install -m 600 ${hostKeyFile} "$TMPDIR/key"
                    derived=$(${pkgs.openssh}/bin/ssh-keygen -y -f "$TMPDIR/key")
                    derived_short=$(echo "$derived" | ${pkgs.coreutils}/bin/cut -d' ' -f1-2)
                    configured_short=$(echo "$configuredPubKey" | ${pkgs.coreutils}/bin/cut -d' ' -f1-2)
                    if [ "$derived_short" != "$configured_short" ]; then
                      echo "initrd SSH keypair mismatch!"
                      echo "Derived from private key: $derived"
                      echo "Configured public key:    $configuredPubKey"
                      exit 1
                    fi
                    touch $out
                  '';
            in
            lib.mkIf hasLuks {
              assertions = [
                {
                  assertion = hostKey != null;
                  message = "host.remote.initrdSSHHostPrivateKey must be set when LUKS devices are present!";
                }
              ];

              boot.initrd.network.enable = true;

              boot.initrd.systemd.network.networks."10-initrd-dhcp" = {
                matchConfig.Type = "ether";
                networkConfig.DHCP = "yes";
              };

              boot.initrd.network.ssh = {
                enable = true;
                port = port;
                hostKeys = lib.optional (hostKey != null) hostKeyFile;
                authorizedKeys = authorizedKeys;
                extraConfig = ''
                  AllowUsers root
                  PasswordAuthentication no
                  KbdInteractiveAuthentication no
                  PermitRootLogin prohibit-password
                  AllowTcpForwarding no
                  X11Forwarding no
                  MaxAuthTries 3
                  MaxSessions 1
                '';
              };

              boot.initrd.systemd.storePaths = [ initrdShell ];
              boot.initrd.systemd.users.root.shell = toString initrdShell;

              system.extraDependencies = lib.optional (hostKey != null && pubKey != null) keypairCheck;
            };
        };
      }
    ];
  };
}
