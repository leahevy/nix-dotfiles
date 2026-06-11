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
  name = "ldap";
  description = "LDAP directory service via OpenLDAP with declarative users and groups";

  group = "server";
  input = "linux";

  options = {
    port = lib.mkOption {
      type = lib.types.int;
      default = 389;
      description = "LDAP listen port exposed to local consumers.";
    };

    homeBase = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/home";
      description = "Base directory under which per-user home directories are created.";
    };

    uidBase = lib.mkOption {
      type = lib.types.int;
      default = 70001;
      description = "Lower bound of the UID range for hash-derived user IDs.";
    };

    uidRange = lib.mkOption {
      type = lib.types.int;
      default = 2000;
      description = "Size of the UID range for hash-derived user and group IDs.";
    };

    baseDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Base domain for LDAP, falls back to host.remote.baseDomain then hostname.local.";
    };

    users = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            username = lib.mkOption {
              type = lib.types.str;
              description = "LDAP user ID and login name.";
            };
            email = lib.mkOption {
              type = lib.types.str;
              description = "Email address for this user.";
            };
            firstname = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Given name, defaults to username with first letter capitalised if not set.";
            };
            lastname = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Family name used as the LDAP sn attribute.";
            };
            uid = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Explicit UID overriding the hash-derived value, use to resolve ID collisions.";
            };
            groups = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Groups this user belongs to.";
            };
          };
        }
      );
      default = [ ];
      description = "Declarative list of LDAP users managed by OpenLDAP.";
    };

    groups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Group names declared in the LDAP directory.";
    };

    ldapUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "LDAP URL set by this module for consumers to read.";
    };

    baseDn = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "LDAP base DN derived from baseDomain, set by this module.";
    };

    bindDn = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Bind DN for service accounts, set by this module.";
    };

    bindPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to the SOPS-decrypted bind password file, set by this module.";
    };

    readerDn = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Read-only service account DN for consumers that only need directory enumeration.";
    };

    readerPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to the SOPS-decrypted reader password file, set by this module.";
    };
  };

  module =
    let
      mkId =
        base: range: name:
        let
          raw = helpers.hexToInt (builtins.substring 0 8 (builtins.hashString "sha256" name));
        in
        base + lib.mod raw range;

      mkLdapRun =
        {
          port,
          bindDn,
          passwordFile,
        }:
        pkgs.writeShellScriptBin "ldap-run" ''
          set -euo pipefail
          if [[ "$EUID" -ne 0 ]]; then
            echo "Must be run as root!"
            exit 1
          fi
          _subcmd="''${1:-}"
          shift || true
          case "$_subcmd" in
            search|add|modify|delete)
              exec "${pkgs.openldap}/bin/ldap$_subcmd" -x -H "ldap://127.0.0.1:${toString port}" -D "${bindDn}" -y "${passwordFile}" "$@" ;;
            *)
              printf 'Usage: ldap-run <search|add|modify|delete> [args...]\n' >&2; exit 1 ;;
          esac
        '';

      effectiveFirstname =
        u:
        if u.firstname != null then
          u.firstname
        else
          lib.toUpper (builtins.substring 0 1 u.username)
          + builtins.substring 1 (builtins.stringLength u.username - 1) u.username;

      effectiveLastname = u: if u.lastname != null then u.lastname else "(person)";

      computeDisplayName =
        u:
        let
          fn = effectiveFirstname u;
          ln = u.lastname;
        in
        if ln != null then "${fn} ${ln}" else fn;
    in
    {
      enabled =
        config:
        let
          domain =
            if config.nx.linux.server.ldap.baseDomain != null then
              config.nx.linux.server.ldap.baseDomain
            else if (self.host.remote.baseDomain or null) != null then
              self.host.remote.baseDomain
            else
              "${self.host.hostname}.local";
          baseDn = lib.concatMapStringsSep "," (p: "dc=${p}") (lib.splitString "." domain);
          port = config.nx.linux.server.ldap.port;
          users = config.nx.linux.server.ldap.users;
          groups = config.nx.linux.server.ldap.groups;
          uidBase = config.nx.linux.server.ldap.uidBase;
          uidRange = config.nx.linux.server.ldap.uidRange;
          usernames = map (u: u.username) users;
          mkNodeId = mkId uidBase uidRange;
          userUid = u: if u.uid != null then u.uid else mkNodeId u.username;
          allUids = map userUid users;
          allGroupGids = map mkNodeId (groups ++ [ "ldap-users" ]);
          allIds = allUids ++ allGroupGids;
        in
        {
          assertions = [
            {
              assertion = builtins.length users <= 1000;
              message = "linux.server.ldap supports at most 1000 users!";
            }
            {
              assertion = builtins.length (lib.unique usernames) == builtins.length usernames;
              message = "linux.server.ldap: duplicate usernames in users list!";
            }
            {
              assertion = builtins.length (lib.unique groups) == builtins.length groups;
              message = "linux.server.ldap: duplicate names in groups list!";
            }
            {
              assertion = !builtins.elem "ldap-users" groups;
              message = "linux.server.ldap: 'ldap-users' is reserved and must not appear in the groups list!";
            }
            {
              assertion = !builtins.elem "ldap-users" usernames;
              message = "linux.server.ldap: 'ldap-users' is reserved and must not be used as a username!";
            }
            {
              assertion = !builtins.elem "nx-ldap-admin" usernames;
              message = "linux.server.ldap: 'nx-ldap-admin' is reserved and must not be used as a username!";
            }
            {
              assertion = !builtins.elem "nx-ldap-admin" groups;
              message = "linux.server.ldap: 'nx-ldap-admin' is reserved and must not appear in the groups list!";
            }
            {
              assertion = !builtins.elem "nx-ldap-reader" usernames;
              message = "linux.server.ldap: 'nx-ldap-reader' is reserved and must not be used as a username!";
            }
            {
              assertion = !builtins.elem "nx-ldap-reader" groups;
              message = "linux.server.ldap: 'nx-ldap-reader' is reserved and must not appear in the groups list!";
            }
            {
              assertion = builtins.length (lib.intersectLists usernames groups) == 0;
              message = "linux.server.ldap: a username and a group name must not be identical!";
            }
            {
              assertion = builtins.length (lib.unique allIds) == builtins.length allIds;
              message = "linux.server.ldap: ID collision detected among UIDs and group GIDs, set an explicit uid on the affected user or change uidBase or uidRange to resolve it!";
            }
          ]
          ++ map (u: {
            assertion = u.username != "";
            message = "linux.server.ldap: username must not be empty!";
          }) users
          ++ map (u: {
            assertion = helpers.isValidEmail u.email;
            message = "linux.server.ldap: email '${u.email}' for user '${u.username}' is not valid!";
          }) users
          ++ lib.concatMap (
            u:
            map (g: {
              assertion = builtins.elem g groups;
              message = "linux.server.ldap: user '${u.username}' references undeclared group '${g}'!";
            }) u.groups
          ) users;

          nx.linux.server.ldap.ldapUrl = "ldap://127.0.0.1:${toString port}";
          nx.linux.server.ldap.baseDn = baseDn;
          nx.linux.server.ldap.bindDn = "cn=nx-ldap-admin,${baseDn}";
          nx.linux.server.ldap.bindPasswordFile = config.sops.secrets."openldap-root-pass".path;
          nx.linux.server.ldap.readerDn = "cn=nx-ldap-reader,${baseDn}";
          nx.linux.server.ldap.readerPasswordFile = config.sops.secrets."openldap-reader-pass".path;
        };

      linux.system =
        {
          config,
          port,
          homeBase,
          uidBase,
          uidRange,
          users,
          groups,
          baseDn,
          bindDn,
          bindPasswordFile,
          ...
        }:
        let
          dcOrg = lib.removePrefix "dc=" (builtins.head (lib.splitString "," baseDn));

          mkNodeId = mkId uidBase uidRange;
          userUid = u: if u.uid != null then u.uid else mkNodeId u.username;
          ldapUsersGid = mkNodeId "ldap-users";

          ldapRunPkg = mkLdapRun {
            inherit port bindDn;
            passwordFile = bindPasswordFile;
          };

          nonEmptyGroups = lib.filter (g: builtins.any (u: builtins.elem g u.groups) users) groups;

          mkUserEntry =
            u:
            "dn: uid=${u.username},ou=people,${baseDn}\n"
            + "objectClass: inetOrgPerson\n"
            + "objectClass: posixAccount\n"
            + "uid: ${u.username}\n"
            + "cn: ${computeDisplayName u}\n"
            + "sn: ${effectiveLastname u}\n"
            + "givenName: ${effectiveFirstname u}\n"
            + "mail: ${u.email}\n"
            + "uidNumber: ${toString (userUid u)}\n"
            + "gidNumber: ${toString (userUid u)}\n"
            + "homeDirectory: ${homeBase}/${u.username}\n"
            + "loginShell: /run/current-system/sw/bin/nologin\n";

          mkGroupEntry =
            g:
            let
              members = lib.filter (u: builtins.elem g u.groups) users;
            in
            "dn: cn=${g},ou=groups,${baseDn}\n"
            + "objectClass: posixGroup\n"
            + "cn: ${g}\n"
            + "gidNumber: ${toString (mkNodeId g)}\n"
            + lib.concatMapStrings (u: "memberUid: ${u.username}\n") members;

          ldapUsersEntry =
            "dn: cn=ldap-users,ou=groups,${baseDn}\n"
            + "objectClass: posixGroup\n"
            + "cn: ldap-users\n"
            + "gidNumber: ${toString ldapUsersGid}\n"
            + lib.concatMapStrings (u: "memberUid: ${u.username}\n") users;

          ldifContents =
            "dn: ${baseDn}\n"
            + "objectClass: dcObject\n"
            + "objectClass: organization\n"
            + "dc: ${dcOrg}\n"
            + "o: ${dcOrg}\n"
            + "\n"
            + "dn: cn=nx-ldap-reader,${baseDn}\n"
            + "objectClass: simpleSecurityObject\n"
            + "objectClass: organizationalRole\n"
            + "cn: nx-ldap-reader\n"
            + "userPassword:< file://${config.sops.secrets."openldap-reader-pass".path}\n"
            + "\n"
            + "dn: ou=people,${baseDn}\n"
            + "objectClass: organizationalUnit\n"
            + "ou: people\n"
            + "\n"
            + "dn: ou=groups,${baseDn}\n"
            + "objectClass: organizationalUnit\n"
            + "ou: groups\n"
            + "\n"
            + lib.concatMapStrings (u: mkUserEntry u + "\n") users
            + (if users != [ ] then ldapUsersEntry + "\n" else "")
            + lib.concatMapStrings (g: mkGroupEntry g + "\n") nonEmptyGroups;
        in
        {
          sops.secrets."openldap-root-pass" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "openldap-root-pass";
            mode = "0400";
            owner = "openldap";
            group = "openldap";
          };

          sops.secrets."openldap-reader-pass" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "openldap-reader-pass";
            mode = "0400";
            owner = "openldap";
            group = "openldap";
          };

          services.openldap = {
            enable = true;
            urlList = [ "ldap://127.0.0.1:${toString port}/" ];
            settings = {
              attrs = {
                olcLogLevel = [ "stats" ];
              };
              children = {
                "cn=schema".includes = [
                  "${helpers.packageFile args pkgs.openldap "etc/schema/core.ldif"}"
                  "${helpers.packageFile args pkgs.openldap "etc/schema/cosine.ldif"}"
                  "${helpers.packageFile args pkgs.openldap "etc/schema/inetorgperson.ldif"}"
                  "${helpers.packageFile args pkgs.openldap "etc/schema/nis.ldif"}"
                ];
                "olcDatabase={1}mdb" = {
                  attrs = {
                    objectClass = [
                      "olcDatabaseConfig"
                      "olcMdbConfig"
                    ];
                    olcDatabase = "{1}mdb";
                    olcDbDirectory = "/var/lib/openldap/data";
                    olcSuffix = baseDn;
                    olcRootDN = "cn=nx-ldap-admin,${baseDn}";
                    olcRootPW = {
                      path = config.sops.secrets."openldap-root-pass".path;
                    };
                    olcAccess = [
                      "to attrs=userPassword by anonymous auth by * none"
                      "to * by dn.exact=\"cn=nx-ldap-reader,${baseDn}\" read by * none"
                    ];
                  };
                };
              };
            };
            declarativeContents = {
              "${baseDn}" = ldifContents;
            };
          };

          users.users = lib.listToAttrs (
            map (u: {
              name = u.username;
              value = {
                uid = userUid u;
                isNormalUser = true;
                home = "${homeBase}/${u.username}";
                homeMode = "700";
                createHome = true;
                shell = "${pkgs.shadow}/bin/nologin";
                group = u.username;
                extraGroups = [ "ldap-users" ] ++ u.groups;
              };
            }) users
          );

          users.groups = {
            ldap-users.gid = ldapUsersGid;
          }
          // lib.listToAttrs (
            map (u: {
              name = u.username;
              value.gid = userUid u;
            }) users
          )
          // lib.listToAttrs (
            map (g: {
              name = g;
              value.gid = mkNodeId g;
            }) groups
          );

          systemd.tmpfiles.settings."ldap-homes" = lib.listToAttrs (
            lib.concatMap (
              u:
              let
                entry = {
                  mode = "0700";
                  user = u.username;
                  group = u.username;
                };
              in
              [
                {
                  name = "${homeBase}/${u.username}";
                  value."d" = entry;
                }
              ]
              ++ lib.optional self.host.impermanence {
                name = "${self.persist}${homeBase}/${u.username}";
                value."d" = entry;
              }
            ) users
          );

          environment.systemPackages = [ ldapRunPkg ];

          environment.persistence."${self.persist}" = {
            directories = map (u: "${homeBase}/${u.username}") users;
          };
        };

      ifEnabled.linux.server.healthchecks = {
        enabled =
          config:
          let
            homeBase = config.nx.linux.server.ldap.homeBase;
            users = config.nx.linux.server.ldap.users;
            groups = config.nx.linux.server.ldap.groups;
            baseDn = config.nx.linux.server.ldap.baseDn;
            port = config.nx.linux.server.ldap.port;
            uidBase = config.nx.linux.server.ldap.uidBase;
            uidRange = config.nx.linux.server.ldap.uidRange;
            mkNodeId = mkId uidBase uidRange;
            userUid = u: if u.uid != null then u.uid else mkNodeId u.username;
            ldapRunPkg = mkLdapRun {
              inherit port;
              bindDn = config.nx.linux.server.ldap.bindDn;
              passwordFile = config.nx.linux.server.ldap.bindPasswordFile;
            };
            ldapRun = lib.getExe ldapRunPkg;
            mkContentCheck =
              bindDn: passwordFile:
              let
                ldapSearch = "${pkgs.openldap}/bin/ldapsearch -x -H \"ldap://127.0.0.1:${toString port}\" -D \"${bindDn}\" -y \"${passwordFile}\"";
              in
              ''
                ${ldapRun} search -b "${baseDn}" -s base "(objectClass=*)" >/dev/null 2>&1 || exit 0
                _ldap_people=$(${ldapSearch} -b "ou=people,${baseDn}" -s one "(objectClass=inetOrgPerson)" uid 2>&1) || {
                  printf 'ldapsearch people failed: %s\n' "$_ldap_people" >&3
                  exit 1
                }
                _ldap_groups=$(${ldapSearch} -b "ou=groups,${baseDn}" -s one "(objectClass=posixGroup)" cn 2>&1) || {
                  printf 'ldapsearch groups failed: %s\n' "$_ldap_groups" >&3
                  exit 1
                }
                ${lib.concatMapStrings (u: ''
                  if ! printf '%s' "$_ldap_people" | ${pkgs.gnugrep}/bin/grep -q "^uid: ${u.username}$"; then
                    printf 'user ${u.username} not found in LDAP\n' >&3
                    exit 1
                  fi
                '') users}
                ${lib.concatMapStrings (g: ''
                  if ! printf '%s' "$_ldap_groups" | ${pkgs.gnugrep}/bin/grep -q "^cn: ${g}$"; then
                    printf 'group ${g} not found in LDAP\n' >&3
                    exit 1
                  fi
                '') (groups ++ lib.optional (users != [ ]) "ldap-users")}
              '';
          in
          {
            nx.linux.server.healthchecks.requireServicesUp = [ "openldap.service" ];
            nx.linux.server.healthchecks.regularHealthChecks = {
              "+36 - LDAP home directories" =
                "_ldap_dir_fail=0\n"
                + lib.concatMapStrings (
                  u:
                  let
                    uid = toString (userUid u);
                  in
                  ''
                    _ldap_home="${homeBase}/${u.username}"
                    _ldap_uid="${uid}"
                    if [[ ! -d "$_ldap_home" ]]; then
                      printf 'home dir missing for ${u.username}: %s\n' "$_ldap_home" >&3
                      _ldap_dir_fail=1
                    else
                      _ldap_mode=$(${pkgs.coreutils}/bin/stat -c %a "$_ldap_home" 2>/dev/null || echo "0")
                      if [[ "$_ldap_mode" != "700" ]]; then
                        printf 'wrong permissions on %s: %s (expected 700)\n' "$_ldap_home" "$_ldap_mode" >&3
                        _ldap_dir_fail=1
                      fi
                      _ldap_owner=$(${pkgs.coreutils}/bin/stat -c %u "$_ldap_home" 2>/dev/null || echo "0")
                      if [[ "$_ldap_owner" != "$_ldap_uid" ]]; then
                        printf 'wrong owner on %s: %s (expected %s)\n' "$_ldap_home" "$_ldap_owner" "$_ldap_uid" >&3
                        _ldap_dir_fail=1
                      fi
                    fi
                  ''
                ) users
                + ''
                  if [[ "$_ldap_dir_fail" -ne 0 ]]; then exit 1; fi
                '';

              "R+37 - LDAP reachability" = ''
                _ldap_out=$(${ldapRun} search -b "${baseDn}" -s base "(objectClass=*)" 2>&1) || {
                  printf 'ldapsearch failed: %s\n' "$_ldap_out" >&3
                  exit 1
                }
              '';
            }
            // lib.listToAttrs (
              map
                (
                  {
                    label,
                    bindDn,
                    passwordFile,
                  }:
                  {
                    name = label;
                    value = mkContentCheck bindDn passwordFile;
                  }
                )
                [
                  {
                    label = "R+38 - LDAP content";
                    bindDn = config.nx.linux.server.ldap.bindDn;
                    passwordFile = config.nx.linux.server.ldap.bindPasswordFile;
                  }
                  {
                    label = "R+39 - LDAP content (reader)";
                    bindDn = config.nx.linux.server.ldap.readerDn;
                    passwordFile = config.nx.linux.server.ldap.readerPasswordFile;
                  }
                ]
            );
          };
      };
    };
}
