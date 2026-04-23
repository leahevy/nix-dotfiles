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
  name = "codex";

  group = "dev";
  input = "common";

  module = {
    home =
      config:
      let
        gitUrl = (config.programs.git.settings.url or { });
        githubEnforceSSH =
          gitUrl ? "git@github.com:"
          && (
            let
              entry = gitUrl."git@github.com:";
              insteadOf = entry.insteadOf or null;
            in
            if lib.isList insteadOf then
              lib.any (v: lib.hasPrefix "https://github.com/" v) insteadOf
            else
              lib.isString insteadOf && lib.hasPrefix "https://github.com/" insteadOf
          );

        fake-ssh = pkgs.writeShellScriptBin "ssh" "exit 1";
        codex-wrapped = pkgs.symlinkJoin {
          name = "codex-wrapped";
          paths = [ pkgs.codex ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram "$out/bin/codex" \
              --prefix PATH : ${fake-ssh}/bin \
              --set GIT_CONFIG_COUNT 1 \
              --set GIT_CONFIG_KEY_0 "url.https://github.com/.insteadOf" \
              --set GIT_CONFIG_VALUE_0 "git@github.com:"
          '';
        };
        codex-package =
          if githubEnforceSSH && config.nx.linux.security.yubikey.enable then codex-wrapped else pkgs.codex;
      in
      {
        programs.codex = {
          enable = true;
          package = codex-package;
        };

        home.persistence."${self.persist}" = {
          directories = [ ".codex" ];
        };
      };
  };
}
