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
  name = "git";

  group = "git";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      shell = {
        rust-programs = true;
      };
    };
  };

  settings = {
    serversToEnforceSSH = [
      "github.com"
      "gitlab.com"
    ];
    useDifftastic = true;
  };

  configuration =
    context@{ config, options, ... }:
    let
      gpgKey =
        let
          candidate = helpers.ifSet (self.settings.gpg or null) (self.user.gpg or null);
        in
        if candidate != null && candidate != "" then candidate else null;
    in
    {
      programs.git = {
        enable = true;

        settings = {
          user = {
            name = helpers.ifSet (self.settings.name or null) self.user.fullname;
            email = helpers.ifSet (self.settings.email or null) self.user.email;
          };

          signing = {
            key = gpgKey;
            signByDefault = gpgKey != null;
            format = "openpgp";
          };

          init = {
            defaultBranch = "main";
          };

          core = {
            editor = "vim";
            pager = "bat";
            excludesFile = "~/.config/git/gitignore_global";
            whitespace = "-trailing-space";
            autocrlf = "input";
          }
          // lib.optionalAttrs (config.programs.nixvim.enable or false) {
            editor = "nvim";
          };

          help = {
            autocorrect = "prompt";
          };

          url = lib.listToAttrs (
            map (server: {
              name = "git@${server}:";
              value = {
                insteadOf = "https://${server}/";
              };
            }) self.settings.serversToEnforceSSH
          );

          rerere = {
            enabled = true;
          };

          filter = {
            lfs = {
              smudge = "git-lfs smudge -- %f";
              process = "git-lfs filter-process";
              required = "true";
              clean = "git-lfs clean -- %f";
            };
          };

          pull = {
            rebase = "merges";
            autoStash = true;
          };

          rebase = {
            autosquash = true;
            autostash = true;
            missingCommitsCheck = "error";
            updateRefs = true;
          };

          branch = {
            sort = "-committerdate";
          };

          color = {
            branch = {
              current = "yellow reverse";
              local = "yellow";
              remote = "green";
              upstream = "cyan";
            };

            diff = {
              meta = "yellow bold";
              frag = "magenta bold";
              old = "red bold";
              new = "green bold";
            };

            status = {
              added = "yellow";
              changed = "green";
              untracked = "cyan";
            };

            ui = "auto";
          };

          format = {
            pretty = "format:%Cred%h%Creset - %Cgreen%an (%ae) -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset %Cred[%G?]%Creset";
            date = "relative";
          };

          diff = {
            algorithm = "histogram";
            mnemonicPrefix = "true";
            renames = "true";
            rename = "copy";
            wordRegex = ".";
            submodule = "log";
            tool = lib.mkIf (self.settings.useDifftastic) "difftastic";
            colorMoved = "default";
            context = 15;
          };

          difftool = {
            vim = {
              cmd = "vim -d \$LOCAL \$REMOTE";
            };
          };

          submodule = {
            recurse = true;
          };

          fetch = {
            recurseSubmodules = "on-demand";
            fsckobjects = true;
            prune = true;
            prunetags = true;
          };

          receive = {
            fsckobjects = true;
          };

          transfer = {
            fsckobjects = true;
          };

          grep = {
            break = "true";
            heading = "true";
            lineNumber = "true";
            extendedRegexp = "true";
          };

          log = {
            abbrevCommit = "true";
            follow = "true";
            decorate = "false";
            date = "iso";
          };

          commit = {
            verbose = true;
          };

          interactive = {
            singlekey = "true";
          };

          merge = {
            ff = "false";
            conflictstyle = "zdiff3";
            keepbackup = false;
            tool = "vim";
          };

          mergetool = {
            keepBackup = "false";
            keepTemporaries = "false";
            writeToTemp = "true";
            prompt = "false";
          };

          push = {
            default = "current";
            autoSetupRemote = true;
            followTags = "true";
          };

          status = {
            submoduleSummary = "true";
            showUntrackedFiles = "all";
          };

          tag = {
            sort = "version:refname";
            gpgSign = gpgKey != null;
          };

          stash = {
            useBuiltin = "true";
          };

          versionsort = {
            prereleaseSuffix = "-pre .pre -beta .beta -rc .rc";
          };

          http = {
            postBuffer = "157286400";
          };

          alias = {
            co = "checkout";
            br = "branch";
            ci = "commit";
            st = "status";
            addp = "add --patch";
            clean-all = "clean -fdx";
            c = "clean -fdX";
            clean-ignored = "clean -fdX";
            reset-full = "!f() { git clean -fdx; git checkout .; } ; f";
            pack-create = "!f() { git bundle create \$1 --all; git bundle verify \$1; } ; f";
            pack-create-with-stash = "!f() { git bundle create \$1 refs/stash --all; git bundle verify \$1; } ; f";
            pack-fetch-with-stash = "!f() { git fetch \$1 refs/stash; git stash apply FETCH_HEAD; } ; f";
            config-grep = "!f() { git config --get-regexp '.*' | grep \"\$1\" | bat; } ; f";
            aliases = "!git config --get-regexp alias | sed -re 's/alias\\.(\\S*)\\s(.*)$/\\1 = \\2/g'";
            lg = "log --date=relative --pretty=tformat:'%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%an %ad)%Creset %Cred[%G?]%Creset'";
            l = "log --date=relative --pretty=tformat:'%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%an %ad)%Creset %Cred[%G?]%Creset'";
            g = "!f() { git log --graph --pretty=format:'%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset %Cred[%G?]%Creset' --date=relative \$@; } ; f";
            graph = "!f() { git log --graph --pretty=format:'%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset %Cred[%G?]%Creset' --date=relative \$@; } ; f";
            push-all = "!f() { git push --follow-tags \$@; } ; f";
            y = "diff \"@{yesterday}\"";
            w = "whatchanged";
            whatadded = "log --diff-filter=A --";
            dc = "diff --cached";
            d = "diff";
            a = "add --patch";
            diffc = "diff --cached";
            head = "show HEAD";
            h = "show HEAD";
            patch-create = "format-patch -k --stdout";
            patch-create-head = "format-patch -k --stdout HEAD~1";
            patch-apply = "am -3 -k";
            rebase-origin = "rebase -i origin/HEAD";
            amendfiles = "commit --amend --no-edit";
            review-local = "!git lg @{push}..";
            reword = "commit --amend";
            uncommit = "reset --soft HEAD~1";
            unstage = "reset";
            untrack = "rm --cache --";
            conflicts = "diff --name-only --diff-filter=U";
          };
        };
      };

      programs.difftastic = lib.mkIf self.settings.useDifftastic {
        enable = true;
        git = {
          diffToolMode = true;
        };
        options = {
          background = "dark";
          color = "always";
          display = "inline";
        };
      };

      home.file.".config/git/gitignore_global" = {
        source = self.symlinkFile config "gitignore_global";
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/git"
        ];
        files = [
          ".gitconfig"
        ];
      };
    };
}
