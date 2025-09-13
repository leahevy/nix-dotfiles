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
let
  host = self.host;
  users = self.users;
  ifSet = helpers.ifSet;
in
{
  name = "users";

  configuration =
    context@{ config, options, ... }:
    {
      sops = {
        secrets = {
          userPasswordHash = {
            sopsFile = helpers.secretsPath "user-secrets.yaml";
            neededForUsers = true;
          };
        };
      };

      users.mutableUsers = false;
      users.users =
        let
          allUsers = builtins.attrValues users;

          normalUsers = lib.filterAttrs (_: user: !(ifSet user.system.isSystemUser false)) users;
          nonNormalUsers = lib.filterAttrs (_: user: (ifSet user.system.isSystemUser false)) users;

          normalUsersWithUID = lib.listToAttrs (
            lib.lists.imap0 (i: user: {
              name = user.username;
              value = user // {
                uid = 1000 + i;
              };
            }) (builtins.attrValues normalUsers)
          );

          nonNormalUsersWithoutUID = lib.listToAttrs (
            lib.lists.imap0 (i: user: {
              name = user.username;
              value = user;
            }) (builtins.attrValues nonNormalUsers)
          );

          mergedUsers = normalUsersWithUID // nonNormalUsersWithoutUID;

        in
        (builtins.mapAttrs (username: user: {
          uid = if builtins.hasAttr "uid" user then user.uid else null;
          enable = true;
          createHome =
            if user ? home && builtins.isString user.home then (ifSet user.system.createHome true) else false;
          isNormalUser = !(ifSet user.system.isSystemUser false);
          description = "${user.fullname}";
          hashedPasswordFile = if user.isMainUser then config.sops.secrets.userPasswordHash.path else null;
          home = user.home;
          group = ifSet user.system.group user.username;
          extraGroups = (ifSet user.system.extraGroups [ ]) ++ (ifSet host.userDefaults.groups [ ]);
          openssh = {
            authorizedKeys = {
              keys =
                (ifSet (user.settings.sshd or { }).authorizedKeys [ ])
                ++ (ifSet (host.settings.sshd or { }).authorizedKeys [ ]);
            };
          };
          shell =
            if (ifSet user.system.shell "bash") == "bash" then
              pkgs.bash
            else if (ifSet user.system.shell "bash") == "zsh" then
              pkgs.zsh
            else if (ifSet user.system.shell "bash") == "fish" then
              pkgs.fish
            else
              throw "Shell is unknown: ${user.system.shell} for user: ${user.username}";
          linger = ifSet user.system.systemdSessionAtBoot false;
          packages =
            with pkgs;
            [ ]
            ++ (
              if (ifSet user.system.shell "bash") == "bash" then
                [ pkgs.bash ]
              else if (ifSet user.system.shell "bash") == "zsh" then
                [ pkgs.zsh ]
              else if (ifSet user.system.shell "bash") == "fish" then
                [ pkgs.fish ]
              else
                throw "Shell is unknown: ${user.system.shell} for user: ${user.username}"
            );
        }) mergedUsers)
        // {
          root = {
            hashedPassword = null;
          };
        };

      users.groups = builtins.listToAttrs (
        lib.lists.imap0
          (i: group: {
            name = group;
            value = {
              gid = 1000 + i;
            };
          })
          (
            lib.lists.unique (
              (builtins.filter (g: g != null && g != "users") (
                builtins.map (user: ifSet user.system.group user.username) (builtins.attrValues users)
              ))
              ++ (ifSet host.extraGroupsToCreate [ ])
            )
          )
      );
    };
}
