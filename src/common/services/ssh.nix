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
  name = "ssh";

  group = "services";
  input = "common";

  condition = true;

  options = {
    hosts = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "SSH Hosts to configure in ~/.ssh/config";
    };
    termOverride = lib.mkOption {
      type = lib.types.str;
      default = "xterm-256color";
      description = "Override the default terminal type for SSH connections";
    };
    defaultKnownHostsName = lib.mkOption {
      type = lib.types.str;
      default = "known_hosts";
      description = "Filename under ~/.ssh/ to use as the default UserKnownHostsFile for ad-hoc SSH usage";
    };
    managedKnownHostsName = lib.mkOption {
      type = lib.types.str;
      default = "known_hosts_managed";
      description = "Filename under ~/.ssh/ written by this module with auto-generated known_hosts entries (e.g. initrd SSH host keys)";
    };
    configOverridesName = lib.mkOption {
      type = lib.types.str;
      default = "config_overrides";
      description = "Filename under ~/.ssh/ to use for config overrides";
    };
    defaultKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Name of a key in the keys attrset to use as the default SSH identity for all hosts";
    };
    keys = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            public = lib.mkOption {
              type = lib.types.either lib.types.path lib.types.nonEmptyStr;
              description = "SSH public key text or path to a public key file";
            };
            private = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Path to sops-encrypted SSH private key file";
            };
          };
        }
      );
      default = { };
      description = "Named SSH keys for use in host configurations via the key option";
    };
  };

  module = {
    home =
      {
        config,
        hosts,
        termOverride,
        defaultKnownHostsName,
        managedKnownHostsName,
        configOverridesName,
        defaultKey,
        keys,
      }:
      let
        resolveKeyIdentityFile =
          keyName:
          let
            keyEntry = keys.${keyName} or null;
          in
          if keyEntry == null then
            null
          else
            let
              publicText = helpers.sshPublicKeyToString keyEntry.public;
            in
            if keyEntry.private != null then
              config.sops.secrets."ssh-key-${keyName}".path
            else
              toString (pkgs.writeText "${keyName}.pub" publicText);

        defaultSSHIdentityFile =
          if defaultKey != null then
            let
              resolved = resolveKeyIdentityFile defaultKey;
            in
            if resolved == null then throw "SSH defaultKey '${defaultKey}' not found in ssh.keys!" else resolved
          else if self.user.defaultSSHKey != null then
            let
              resolved = resolveKeyIdentityFile self.user.defaultSSHKey;
            in
            if resolved == null then
              throw "SSH user.defaultSSHKey '${self.user.defaultSSHKey}' not found in ssh.keys!"
            else
              resolved
          else
            null;

        defaultKeyPublicText =
          let
            name = if defaultKey != null then defaultKey else self.user.defaultSSHKey;
          in
          if name != null && keys ? ${name} then helpers.sshPublicKeyToString keys.${name}.public else null;

        currentHostname = helpers.resolveFromHost self [ "hostname" ] "";

        lowerFirst =
          s:
          let
            first = lib.substring 0 1 s;
            rest = lib.substring 1 (lib.stringLength s - 1) s;
          in
          (lib.toLower first) + rest;

        isIPv4 = s: (builtins.match "^[0-9]{1,3}(\\.[0-9]{1,3}){3}$" s) != null;

        isIPv6 = s: (builtins.match ".*:.*:.*" s) != null && (builtins.match "^[0-9A-Fa-f:.]+$" s) != null;

        isIp = s: isIPv4 s || isIPv6 s;

        isDomainLoose = s: (builtins.match "^[A-Za-z0-9_][A-Za-z0-9_.-]*\\.[A-Za-z]+$" s) != null;

        isValidHostname = s: isIp s || isDomainLoose s;

        normalSupportedKeysRaw = [
          "AddKeysToAgent"
          "AddressFamily"
          "CertificateFile"
          "Compression"
          "ControlMaster"
          "ControlPath"
          "ControlPersist"
          "DynamicForward"
          "ForwardAgent"
          "ForwardX11"
          "ForwardX11Trusted"
          "Host"
          "Hostname"
          "IdentitiesOnly"
          "IdentityAgent"
          "IdentityFile"
          "LocalForward"
          "Match"
          "Port"
          "ProxyCommand"
          "ProxyJump"
          "RemoteForward"
          "SendEnv"
          "SetEnv"
          "User"
          "UserKnownHostsFile"
        ];

        extraSupportedKeysRaw = [
          "BatchMode"
          "BindAddress"
          "BindInterface"
          "CanonicalDomains"
          "CanonicalizeFallbackLocal"
          "CanonicalizeHostname"
          "CanonicalizeMaxDots"
          "CanonicalizePermittedCNAMEs"
          "CASignatureAlgorithms"
          "ChannelTimeout"
          "CheckHostIP"
          "Ciphers"
          "ClearAllForwardings"
          "ConnectionAttempts"
          "ConnectTimeout"
          "EnableEscapeCommandline"
          "EnableSSHKeysign"
          "EscapeChar"
          "ExitOnForwardFailure"
          "FingerprintHash"
          "ForkAfterAuthentication"
          "ForwardX11Timeout"
          "GatewayPorts"
          "GlobalKnownHostsFile"
          "HashKnownHosts"
          "HostbasedAcceptedAlgorithms"
          "HostbasedAuthentication"
          "HostKeyAlgorithms"
          "HostKeyAlias"
          "IgnoreUnknown"
          "Include"
          "IPQoS"
          "KbdInteractiveAuthentication"
          "KbdInteractiveDevices"
          "KexAlgorithms"
          "KnownHostsCommand"
          "LocalCommand"
          "LogLevel"
          "LogVerbose"
          "MACs"
          "PasswordAuthentication"
          "PermitLocalCommand"
          "PreferredAuthentications"
          "PubkeyAcceptedAlgorithms"
          "PubkeyAuthentication"
          "RDomain"
          "RekeyLimit"
          "RemoteCommand"
          "RequestTTY"
          "ServerAliveCountMax"
          "ServerAliveInterval"
          "SessionType"
          "StdinNull"
          "StreamLocalBindMask"
          "StreamLocalBindUnlink"
          "StrictHostKeyChecking"
          "SyslogFacility"
          "TCPKeepAlive"
          "Tag"
          "Tunnel"
          "TunnelDevice"
          "UpdateHostKeys"
          "VerifyHostKeyDNS"
          "VersionAddendum"
          "VisualHostKey"
          "WarnWeakCrypto"
          "XAuthLocation"
        ];

        normalSupportedKeys = map lowerFirst normalSupportedKeysRaw;
        extraSupportedKeys = map lowerFirst extraSupportedKeysRaw;
        supportedKeys = normalSupportedKeys ++ extraSupportedKeys;

        customKeysRaw = [
          "DisableHostKeyChecking"
          "Key"
          "KnownHostKeys"
          "RequiresPassword"
        ];

        customKeys = map lowerFirst customKeysRaw;

        normalizeBlockKeys =
          block:
          lib.mapAttrs' (
            k: v:
            let
              first = lib.substring 0 1 k;
              rest = lib.substring 1 (lib.stringLength k - 1) k;
              name = (lib.toLower first) + rest;
            in
            {
              inherit name;
              value = v;
            }
          ) block;

        normalizeIdentityFile =
          identityFile:
          if identityFile == null then
            null
          else if lib.hasPrefix "~/" identityFile || lib.hasPrefix "/" identityFile then
            identityFile
          else
            "~/.ssh/${identityFile}";

        preprocessHostBlock =
          hostKey: blockRaw:
          let
            block0 = normalizeBlockKeys blockRaw;
            invalidKeys = lib.filter (k: !(builtins.elem k supportedKeys) && !(builtins.elem k customKeys)) (
              builtins.attrNames block0
            );
            validatedBlock =
              if invalidKeys == [ ] then
                block0
              else
                throw "Invalid SSH matchBlock keys for host '${hostKey}': ${builtins.concatStringsSep ", " invalidKeys}!";

            disableHostKeyChecking = validatedBlock.disableHostKeyChecking or false;
            requiresPassword = validatedBlock.requiresPassword or false;

            hostname = validatedBlock.hostname or hostKey;
            user = validatedBlock.user or self.user.username;
            port = validatedBlock.port or 22;

            identityFile = normalizeIdentityFile (validatedBlock.identityFile or null);

            keyName = validatedBlock.key or null;
            keyPublicText =
              if keyName != null && keys ? ${keyName} then
                helpers.sshPublicKeyToString keys.${keyName}.public
              else
                null;
            keyMatchesDefault =
              keyPublicText != null && defaultKeyPublicText != null && keyPublicText == defaultKeyPublicText;
            keyIdentityFile =
              if keyName == null || keyMatchesDefault then
                null
              else
                let
                  resolved = resolveKeyIdentityFile keyName;
                in
                if resolved == null then throw "SSH key '${keyName}' not found in ssh.keys!" else resolved;

            identitiesOnly =
              if requiresPassword then
                false
              else if validatedBlock ? identitiesOnly then
                validatedBlock.identitiesOnly
              else
                identityFile != null || keyIdentityFile != null;

            visualHostKey = if disableHostKeyChecking then "yes" else "no";

            strictHostKeyChecking =
              if disableHostKeyChecking then
                "no"
              else if validatedBlock ? strictHostKeyChecking then
                validatedBlock.strictHostKeyChecking
              else if (validatedBlock.knownHostKeys or [ ]) != [ ] then
                "yes"
              else
                "ask";

            userKnownHostsFile =
              if disableHostKeyChecking then
                "/dev/null"
              else if validatedBlock ? userKnownHostsFile then
                validatedBlock.userKnownHostsFile
              else if (validatedBlock.knownHostKeys or [ ]) != [ ] then
                "~/.ssh/${managedKnownHostsName}"
              else
                "~/.ssh/${defaultKnownHostsName}";

            logLevel =
              if disableHostKeyChecking then
                (validatedBlock.logLevel or "ERROR")
              else
                (validatedBlock.logLevel or null);

            fixedKnownHostEntries =
              userKnownHostsFile == "~/.ssh/${managedKnownHostsName}" || userKnownHostsFile == "/dev/null";

            hasIdentityFile = identityFile != null || keyIdentityFile != null;

            extraOptionsFromBlock = lib.mapAttrs (k: v: toString v) (
              lib.mapAttrs' (k: v: {
                name = lib.toUpper (lib.substring 0 1 k) + lib.substring 1 (lib.stringLength k - 1) k;
                value = v;
              }) (lib.filterAttrs (k: _: builtins.elem k extraSupportedKeys) validatedBlock)
            );

            extraOptionsGenerated = lib.foldl' lib.recursiveUpdate { } [
              extraOptionsFromBlock
              (lib.optionalAttrs (strictHostKeyChecking != null) {
                StrictHostKeyChecking = strictHostKeyChecking;
              })
              (lib.optionalAttrs (visualHostKey != null) {
                VisualHostKey = visualHostKey;
              })
              (lib.optionalAttrs (logLevel != null) { LogLevel = logLevel; })
              (lib.optionalAttrs fixedKnownHostEntries { CheckHostIP = "no"; })
              (lib.optionalAttrs fixedKnownHostEntries {
                UpdateHostKeys = "no";
                VerifyHostKeyDNS = "no";
              })
              (lib.optionalAttrs (!(validatedBlock ? hashKnownHosts) && hostKey != "*") {
                HashKnownHosts = if fixedKnownHostEntries then "no" else "yes";
              })
              (lib.optionalAttrs (hostKey != "*" && hasIdentityFile && !requiresPassword) {
                PasswordAuthentication = "no";
                KbdInteractiveAuthentication = "no";
                PreferredAuthentications = "publickey";
              })
              (lib.optionalAttrs (hostKey != "*" && requiresPassword) {
                PubkeyAuthentication = "no";
                PasswordAuthentication = "yes";
                KbdInteractiveAuthentication = "yes";
                PreferredAuthentications = "keyboard-interactive,password";
              })
            ];

            knownHostKeyLines =
              let
                rawKeys = validatedBlock.knownHostKeys or [ ];
                prefix = if port == 22 then hostname else "[${hostname}]:${toString port}";
                validated =
                  if builtins.all helpers.validateSSHPublicKey rawKeys then
                    rawKeys
                  else
                    throw "knownHostKeys for host '${hostKey}' contains an invalid SSH public key!";
              in
              if hostname == "*" || rawKeys == [ ] then [ ] else map (key: "${prefix} ${key}") validated;

            block1 =
              let
                baseBlock = lib.filterAttrs (k: _: builtins.elem k normalSupportedKeys) validatedBlock;

                computedBlock = {
                  inherit
                    user
                    port
                    userKnownHostsFile
                    identitiesOnly
                    ;
                }
                // lib.optionalAttrs (hostname != "*") {
                  inherit hostname;
                };

                resolvedIdentityFile =
                  if identityFile != null then
                    identityFile
                  else if keyIdentityFile != null then
                    keyIdentityFile
                  else
                    defaultSSHIdentityFile;

                identityBlock =
                  lib.optionalAttrs
                    (resolvedIdentityFile != null && (hostKey == "*" || resolvedIdentityFile != defaultSSHIdentityFile))
                    {
                      identityFile = resolvedIdentityFile;
                    };
                extraOptionsBlock = lib.optionalAttrs (extraOptionsGenerated != { }) {
                  extraOptions = extraOptionsGenerated;
                };
              in
              lib.recursiveUpdate baseBlock (
                lib.recursiveUpdate computedBlock (lib.recursiveUpdate identityBlock extraOptionsBlock)
              );
          in
          {
            block = block1;
            knownHostKeys = knownHostKeyLines;
          };

        autoHosts =
          let
            hostsFromInventory = lib.mapAttrsToList (
              profileName: hostCfg:
              let
                remoteAddress = hostCfg.remote.address or null;
                remotePort = hostCfg.remote.port or 22;
                hostname = hostCfg.hostname or "";
                username = (hostCfg.mainUser.username or self.user.username);
              in
              if remoteAddress == null || remoteAddress == "" || hostname == currentHostname then
                null
              else
                {
                  name =
                    let
                      entryName =
                        if username == "initrd" then "initrd-user-${profileName}" else "${username}.${profileName}";
                    in
                    entryName;
                  value = {
                    user = username;
                    hostname = remoteAddress;
                    port = remotePort;
                  };
                }
            ) (self.nixOSHosts or { });
          in
          builtins.listToAttrs (builtins.filter (x: x != null) hostsFromInventory);

        initrdHosts = builtins.listToAttrs (
          builtins.filter (x: x != null) (
            lib.mapAttrsToList (
              profileName: hostCfg:
              let
                remoteAddress = hostCfg.remote.address or null;
                initrdHostKey = hostCfg.remote.initrdSSHHostPrivateKey or null;
                initrdHostPubKey = hostCfg.remote.initrdSSHHostPublicKey or null;
                initrdPort = hostCfg.remote.initrdSSHExposedPort or 2233;
                hostname = hostCfg.hostname or "";
                installKey = self.variables.isoManagementSSHKey or null;
              in
              if
                remoteAddress == null || remoteAddress == "" || hostname == currentHostname || initrdHostKey == null
              then
                null
              else
                {
                  name = "initrd.${profileName}";
                  value = {
                    user = "root";
                    hostname = remoteAddress;
                    port = initrdPort;
                  }
                  // lib.optionalAttrs (initrdHostPubKey != null) {
                    knownHostKeys = [ initrdHostPubKey ];
                  }
                  // lib.optionalAttrs (installKey != null) {
                    key = "nx-install";
                  };
                }
            ) (self.nixOSHosts or { })
          )
        );

        getBlockHostname =
          hostKey: block:
          toString (
            if block ? hostname then
              block.hostname
            else if block ? Hostname then
              block.Hostname
            else
              hostKey
          );

        duplicateHostsForIpHostnames =
          hosts0:
          let
            candidateEntries = lib.flatten (
              lib.mapAttrsToList (
                hostKey: block:
                let
                  hn = getBlockHostname hostKey block;
                  port = block.port or block.Port or 22;
                in
                if isIp hn && hostKey != hn && !(hosts0 ? "${hn}") then
                  [
                    {
                      inherit hn port block;
                    }
                  ]
                else
                  [ ]
              ) hosts0
            );

            ipToCandidates = lib.foldl' (
              acc: entry:
              acc
              // {
                "${entry.hn}" = (acc."${entry.hn}" or [ ]) ++ [ entry ];
              }
            ) { } candidateEntries;

            additions = lib.flatten (
              lib.mapAttrsToList (
                ip: candidates:
                let
                  defaultPortCandidates = builtins.filter (c: toString c.port == "22") candidates;
                in
                if builtins.length defaultPortCandidates == 1 then
                  [
                    {
                      name = ip;
                      value = (builtins.head defaultPortCandidates).block // {
                        hostname = ip;
                      };
                    }
                  ]
                else
                  [ ]
              ) ipToCandidates
            );
          in
          hosts0 // builtins.listToAttrs additions;

        isManagingMachine =
          config.nx.global.deploymentMode == "local" || config.nx.global.deploymentMode == "develop";

        processedHostsWithKeys = lib.mapAttrs preprocessHostBlock (
          duplicateHostsForIpHostnames (
            (lib.optionalAttrs isManagingMachine autoHosts)
            // (lib.optionalAttrs isManagingMachine initrdHosts)
            // hosts
            // {
              "*" = {
                user = "${self.user.username}";
                userKnownHostsFile = "~/.ssh/${defaultKnownHostsName}";
                hashKnownHosts = "yes";
                VerifyHostKeyDNS = "ask";
                UpdateHostKeys = "yes";
                ForwardX11 = false;
                ForwardX11Trusted = false;
                Tunnel = "no";
                PermitLocalCommand = "no";
                PubkeyAuthentication = "yes";
                PasswordAuthentication = "yes";
                KbdInteractiveAuthentication = "yes";
                HostbasedAuthentication = "no";
                Compression = false;
                VisualHostKey = "no";
                Ciphers = "-3des-cbc,-aes128-cbc,-aes192-cbc,-aes256-cbc";
                MACs = "-hmac-sha1,-hmac-sha1-96,-hmac-md5,-hmac-md5-96,-umac-64@openssh.com,-hmac-sha1-etm@openssh.com,-hmac-sha1-96-etm@openssh.com,-hmac-md5-etm@openssh.com,-hmac-md5-96-etm@openssh.com,-umac-64-etm@openssh.com";
                KexAlgorithms = "-diffie-hellman-group1-sha1,-diffie-hellman-group14-sha1,-diffie-hellman-group-exchange-sha1,-ecdh-sha2-nistp*";
                HostKeyAlgorithms = "-ssh-dss*";
                PubkeyAcceptedAlgorithms = "-ssh-dss*,-ssh-rsa*";
                addKeysToAgent = "yes";
                strictHostKeyChecking = "ask";
                CheckHostIP = "yes";
                preferredAuthentications = "publickey,keyboard-interactive,password";
                serverAliveInterval = 30;
                serverAliveCountMax = 15;
                TCPKeepAlive = "yes";
                connectTimeout = 30;
                connectionAttempts = 3;
              }
              // lib.optionalAttrs (termOverride != null) {
                setEnv = {
                  TERM = termOverride;
                };
              }
              // lib.optionalAttrs (defaultSSHIdentityFile != null) {
                identityFile = defaultSSHIdentityFile;
              };
            }
          )
        );

        processedHosts = lib.mapAttrs (_: x: x.block) processedHostsWithKeys;

        managedKnownHostsLines = lib.unique (
          lib.flatten (lib.mapAttrsToList (_: x: x.knownHostKeys) processedHostsWithKeys)
        );

        sshConfigMarker = "# SSH-Config generated by Home-Manager";
      in
      {
        assertions = [
          {
            assertion =
              let
                file = config.home.file;
                hasText = file ? ".ssh/config" && file.".ssh/config" ? text;
                content = if hasText then file.".ssh/config".text else "";
              in
              hasText && lib.strings.hasInfix sshConfigMarker content;
            message = "Do not use home.file for ssh config. Instead configure with common.services.ssh module!";
          }
        ]
        ++ lib.mapAttrsToList (
          hostKey: blockRaw:
          let
            block0 = normalizeBlockKeys blockRaw;
            hn = toString (block0.hostname or "");
          in
          {
            assertion = !(block0 ? hostname) || hn == "*" || isValidHostname hn;
            message = "SSH host '${hostKey}': hostname must be a domain or IP address!";
          }
        ) hosts
        ++ lib.flatten (
          lib.mapAttrsToList (
            profileName: hostCfg:
            let
              hasPriv = (hostCfg.remote.initrdSSHHostPrivateKey or null) != null;
              hasPub = (hostCfg.remote.initrdSSHHostPublicKey or null) != null;
            in
            [
              {
                assertion = !hasPriv || hasPub;
                message = "Host '${profileName}': host.remote.initrdSSHHostPublicKey must be set when initrdSSHHostPrivateKey is configured!";
              }
              {
                assertion = !hasPub || hasPriv;
                message = "Host '${profileName}': host.remote.initrdSSHHostPrivateKey must be set when initrdSSHHostPublicKey is configured!";
              }
            ]
          ) (self.nixOSHosts or { })
        )
        ++ lib.flatten (
          lib.mapAttrsToList (
            keyName: keyEntry:
            let
              publicText = helpers.sshPublicKeyToString keyEntry.public;
            in
            [
              {
                assertion = helpers.validateSSHPublicKey publicText;
                message = "ssh.keys.${keyName}.public is not a valid SSH public key!";
              }
            ]
            ++ lib.optional (keyEntry.private != null) {
              assertion =
                let
                  content = builtins.readFile keyEntry.private;
                  result = builtins.tryEval (
                    let
                      p = builtins.fromJSON content;
                    in
                    p ? data && p ? sops
                  );
                in
                lib.hasInfix "sops" content && result.success && result.value;
              message = "ssh.keys.${keyName}.private is not a valid sops encrypted file!";
            }
          ) keys
        );

        home.file.".ssh/${managedKnownHostsName}" = {
          text =
            "# Known hosts generated by Home-Manager\n"
            + lib.concatStringsSep "\n" managedKnownHostsLines
            + (if managedKnownHostsLines != [ ] then "\n" else "");
        };

        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
          matchBlocks = processedHosts;
          extraOptionOverrides = {
            Include = "~/.ssh/${configOverridesName}";
          };
          extraConfig = "\n${sshConfigMarker}\n";
        };

        sops.secrets = builtins.listToAttrs (
          lib.flatten (
            lib.mapAttrsToList (
              keyName: keyEntry:
              lib.optional (keyEntry.private != null) {
                name = "ssh-key-${keyName}";
                value = {
                  sopsFile = keyEntry.private;
                  mode = "0600";
                  format = "binary";
                };
              }
            ) keys
          )
        );

        home.activation.create_ssh_files = (self.hmLib config).dag.entryAfter [ "writeBoundary" ] ''
          ${pkgs.coreutils}/bin/touch "${self.user.home}/.ssh/${defaultKnownHostsName}" || true
          ${pkgs.coreutils}/bin/touch "${self.user.home}/.ssh/${configOverridesName}" || true
        '';
      };
  };
}
