args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  nixpkgsRev = self.inputs.nixpkgs.rev;
  nixpkgsUnstableRev = self.inputs.nixpkgs-unstable.rev;
  devenvRev = self.inputs.devenv.rev;
  nixpkgsPythonRev = self.inputs.nixpkgs-python.rev;

  devenvTemplate = pkgs.writeText "devenv.nix" ''
    { pkgs, lib, inputs, ... }:
    {
      cachix.enable = false;

      overlays = [
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable { system = prev.stdenv.system; };
        })
      ];

      imports =
        let
          devDir = ./.dev;
        in
        if builtins.pathExists devDir then
          lib.mapAttrsToList (name: _: "''${devDir}/''${name}") (
            lib.filterAttrs (
              name: _: lib.hasSuffix ".nix" name && builtins.readFile "''${devDir}/''${name}" != ""
            ) (builtins.readDir devDir)
          )
        else
          [ ];
    }
  '';

  devenvYamlTemplate = pkgs.writeText "devenv.yaml" ''
    inputs:
      nixpkgs:
        url: github:NixOS/nixpkgs/${nixpkgsRev}
      nixpkgs-unstable:
        url: github:NixOS/nixpkgs/${nixpkgsUnstableRev}
      devenv:
        url: github:cachix/devenv/${devenvRev}
      nixpkgs-python:
        url: github:cachix/nixpkgs-python/${nixpkgsPythonRev}
  '';

  envrcTemplate = pkgs.writeText "dev-envrc" ''
    eval "$(devenv direnvrc)"

    use devenv
  '';

  languages = {
    uv = {
      options = {
        languages.python.enable = true;
        languages.python.venv.enable = true;
        languages.python.uv.enable = true;
        languages.python.uv.sync.enable = true;
      };
      conflict = "poetry";
      version = [
        "languages.python.enable = true;"
        "languages.python.version = \"{version}\";"
      ];
      adder = [
        "uv"
        "add"
      ];
    };

    poetry = {
      options = {
        languages.python.enable = true;
        languages.python.poetry.enable = true;
        languages.python.poetry.activate.enable = true;
        languages.python.poetry.install.enable = true;
      };
      conflict = "uv";
      version = [
        "languages.python.enable = true;"
        "languages.python.version = \"{version}\";"
      ];
      adder = [
        "poetry"
        "add"
      ];
    };

    go = {
      options = {
        languages.go.enable = true;
      };
      adder = [
        "go"
        "get"
      ];
    };

    rust = {
      options = {
        languages.rust.enable = true;
      };
      adder = [
        "cargo"
        "add"
      ];
    };

    dotenv = {
      options = {
        dotenv.enable = true;
      };
    };
  };

  languageNames = lib.attrNames languages;

  flattenOptions =
    prefix: value:
    if builtins.isAttrs value then
      lib.concatMap (
        name: flattenOptions (if prefix == "" then name else "${prefix}.${name}") value.${name}
      ) (lib.attrNames value)
    else
      [ "${prefix} = ${lib.generators.toPretty { } value};" ];

  renderFragmentText =
    language:
    let
      lines =
        flattenOptions "" (language.options or { })
        ++ lib.optional (language ? extraFragmentText) language.extraFragmentText;
    in
    ''
      { pkgs, ... }:
      {
        ${lib.concatStringsSep "\n  " lines}
      }
    '';

  languageFragments = lib.mapAttrs (
    name: language: pkgs.writeText "${name}.nix" (renderFragmentText language)
  ) languages;

  languagesWithAdder = lib.filterAttrs (_: language: language ? adder) languages;

  fragmentsJson = builtins.toJSON (lib.mapAttrs (name: _: "${languageFragments.${name}}") languages);
  conflictsJson = builtins.toJSON (
    lib.mapAttrs (_: language: language.conflict) (
      lib.filterAttrs (_: language: language ? conflict) languages
    )
  );
  versionInsertsJson = builtins.toJSON (
    lib.mapAttrs (_: language: language.version) (
      lib.filterAttrs (_: language: language ? version) languages
    )
  );
  addersJson = builtins.toJSON (lib.mapAttrs (_: language: language.adder) languagesWithAdder);
  langsJson = builtins.toJSON languageNames;

  enableCompletionNames = lib.concatStringsSep " " languageNames;
  addCompletionNames = lib.concatStringsSep " " (lib.attrNames languagesWithAdder);

  colorHelper = ''
    def _supports_color(stream):
        return (
            stream.isatty()
            and os.environ.get("NO_COLOR") is None
            and os.environ.get("TERM") != "dumb"
        )


    def _wrap(code, text, stream):
        return "\033[" + code + "m" + text + "\033[0m" if _supports_color(stream) else text


    def green(text):
        return _wrap("1;32", text, sys.stdout)


    def yellow(text):
        return _wrap("1;33", text, sys.stdout)


    def red(text):
        return _wrap("1;31", text, sys.stderr)
  '';

  gitExcludePathHelper = ''
    def git_exclude_path():
        return subprocess.run(
            ["git", "rev-parse", "--git-path", "info/exclude"],
            stdout=subprocess.PIPE,
            text=True,
            check=True,
        ).stdout.strip()
  '';

  addGitExcludesHelper = ''
    ${gitExcludePathHelper}

    def add_git_excludes(entries):
        path = git_exclude_path()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        existing = []
        if os.path.exists(path):
            with open(path) as handle:
                existing = [line.rstrip("\n") for line in handle]
        with open(path, "a") as handle:
            for entry in entries:
                if entry not in existing:
                    handle.write(entry + "\n")
  '';

  subcommands = {
    init = {
      desc = "Scaffold a devenv project in the current directory";
      text = ''
        import os
        import shutil
        import subprocess
        import sys

        DEVENV_TEMPLATE = "${devenvTemplate}"
        DEVENV_YAML_TEMPLATE = "${devenvYamlTemplate}"
        ENVRC_TEMPLATE = "${envrcTemplate}"

        EXCLUDES = ["devenv.nix", "devenv.yaml", "devenv.lock"]


        ${colorHelper}

        ${addGitExcludesHelper}

        def write_file(src, dest, force):
            if force or not os.path.exists(dest):
                shutil.copyfile(src, dest)


        def is_git_tracked(path):
            return (
                subprocess.run(
                    ["git", "ls-files", "--error-unmatch", path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                ).returncode
                == 0
            )


        def main():
            force = "--force" in sys.argv[1:]
            has_devdir = os.path.isdir(".dev")
            has_devenv = os.path.isfile("devenv.nix")
            if not has_devdir and has_devenv and not force:
                print(
                    red(
                        "dev: devenv.nix present but no .dev/ (existing devenv project). "
                        "Re-run with --force to scaffold anyway."
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)
            write_file(DEVENV_TEMPLATE, "devenv.nix", force)
            write_file(DEVENV_YAML_TEMPLATE, "devenv.yaml", force)
            if not is_git_tracked(".envrc"):
                write_file(ENVRC_TEMPLATE, ".envrc", force)
            os.makedirs(".dev", exist_ok=True)
            add_git_excludes(EXCLUDES)
            if has_devdir:
                print(yellow("dev: already initialised (.dev/ present)"))
            else:
                print(green("dev: initialised. Run `direnv allow` (or `dev shell`)."))


        if __name__ == "__main__":
            main()
      '';
    };

    enable = {
      desc = "Enable a feature";
      text = ''
        import os
        import shutil
        import sys

        FRAGMENTS = ${fragmentsJson}

        CONFLICTS = ${conflictsJson}

        VERSION_INSERTS = ${versionInsertsJson}


        ${colorHelper}

        def main():
            args = sys.argv[1:]
            if not args or args[0] not in FRAGMENTS:
                langs = ", ".join(sorted(FRAGMENTS))
                print(red("usage: dev enable <" + langs + "> [version]"), file=sys.stderr)
                sys.exit(1)
            lang = args[0]
            rest = args[1:]
            version = None
            if rest:
                if lang not in VERSION_INSERTS:
                    print(
                        red("dev: " + lang + " does not take a version argument"),
                        file=sys.stderr,
                    )
                    sys.exit(1)
                if len(rest) != 1:
                    print(red("usage: dev enable " + lang + " [version]"), file=sys.stderr)
                    sys.exit(1)
                version = rest[0]
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            os.makedirs(".dev", exist_ok=True)
            dest = os.path.join(".dev", lang + ".nix")
            already_enabled = os.path.exists(dest)
            if already_enabled and version is None:
                print(yellow("dev: " + lang + " already enabled"))
                return
            conflict = CONFLICTS.get(lang)
            if conflict and os.path.exists(os.path.join(".dev", conflict + ".nix")):
                print(
                    red(
                        "dev: "
                        + lang
                        + " conflicts with "
                        + conflict
                        + " (both manage Python dependencies). Run `dev disable "
                        + conflict
                        + "` first!"
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)
            if version is None:
                shutil.copyfile(FRAGMENTS[lang], dest)
            else:
                marker, option_template = VERSION_INSERTS[lang]
                with open(FRAGMENTS[lang]) as handle:
                    content = handle.read()
                content = content.replace(
                    marker,
                    marker + "\n  " + option_template.format(version=version),
                    1,
                )
                with open(dest, "w") as handle:
                    handle.write(content)
            if already_enabled:
                print(green("dev: " + lang + " updated (version " + version + ")"))
            else:
                suffix = " (version " + version + ")" if version else ""
                print(green("dev: enabled " + lang + suffix))


        if __name__ == "__main__":
            main()
      '';
    };

    disable = {
      desc = "Disable a feature";
      text = ''
        import os
        import sys

        LANGS = ${langsJson}


        ${colorHelper}

        def main():
            args = sys.argv[1:]
            if len(args) != 1 or args[0] not in LANGS:
                print(red("usage: dev disable <" + "|".join(LANGS) + ">"), file=sys.stderr)
                sys.exit(1)
            lang = args[0]
            dest = os.path.join(".dev", lang + ".nix")
            if not os.path.exists(dest):
                print(yellow("dev: " + lang + " not enabled"))
                return
            os.remove(dest)
            print(green("dev: disabled " + lang))


        if __name__ == "__main__":
            main()
      '';
    };

    list = {
      desc = "List enabled features";
      text = ''
        import os
        import sys


        ${colorHelper}

        def main():
            devdir = ".dev"
            if not os.path.isdir(devdir):
                print(yellow("dev: not a dev project (no .dev/)"))
                return
            frags = sorted(
                name[:-4]
                for name in os.listdir(devdir)
                if name.endswith(".nix") and name not in ("devenv.local.nix", "packages.nix")
            )
            if not frags:
                print(yellow("dev: no features enabled"))
                return
            for name in frags:
                print(name)


        if __name__ == "__main__":
            main()
      '';
    };

    shell = {
      desc = "Enter the dev shell";
      text = ''
        import os


        def main():
            os.execvp("devenv", ["devenv", "shell"])


        if __name__ == "__main__":
            main()
      '';
    };

    run = {
      desc = "Run a command in the dev shell";
      text = ''
        import os
        import sys


        ${colorHelper}

        def main():
            args = sys.argv[1:]
            if not args:
                print(red("usage: dev run <cmd> [args...]"), file=sys.stderr)
                sys.exit(1)
            os.execvp("devenv", ["devenv", "shell", "--"] + args)


        if __name__ == "__main__":
            main()
      '';
    };

    add = {
      desc = "Add a dependency to the enabled language";
      text = ''
        import os
        import sys

        ADDERS = ${addersJson}


        ${colorHelper}

        def main():
            args = sys.argv[1:]
            lang = None
            if args[:1] == ["--lang"]:
                if len(args) < 2:
                    print(red("usage: dev add --lang <lang> <pkg> [pkg...]"), file=sys.stderr)
                    sys.exit(1)
                lang = args[1]
                args = args[2:]
                if lang not in ADDERS:
                    print(red("dev: unknown language '" + lang + "'"), file=sys.stderr)
                    sys.exit(1)
            if not args:
                print(red("usage: dev add [--lang <lang>] <pkg> [pkg...]"), file=sys.stderr)
                sys.exit(1)
            enabled = [
                name for name in ADDERS if os.path.exists(os.path.join(".dev", name + ".nix"))
            ]
            if lang is not None:
                if lang not in enabled:
                    print(
                        red(
                            "dev: "
                            + lang
                            + " is not enabled. Run `dev enable "
                            + lang
                            + "` first!"
                        ),
                        file=sys.stderr,
                    )
                    sys.exit(1)
            elif not enabled:
                print(
                    red("dev: no language enabled to add to. Run `dev enable <lang>` first!"),
                    file=sys.stderr,
                )
                sys.exit(1)
            elif len(enabled) > 1:
                print(
                    red(
                        "dev: multiple languages enabled ("
                        + ", ".join(sorted(enabled))
                        + "); use --lang to pick one, e.g. `dev add --lang "
                        + enabled[0]
                        + " "
                        + " ".join(args)
                        + "`"
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)
            else:
                lang = enabled[0]
            os.execvp("devenv", ["devenv", "shell", "--"] + ADDERS[lang] + args)


        if __name__ == "__main__":
            main()
      '';
    };

    pkg = {
      desc = "Add or remove Nix packages (dev pkg add/remove <name>...)";
      text = ''
        import json
        import os
        import re
        import sys

        PACKAGES_JSON = os.path.join(".dev", "packages.json")
        PACKAGES_NIX = os.path.join(".dev", "packages.nix")
        NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_'-]*(\.[A-Za-z_][A-Za-z0-9_'-]*)*$")


        ${colorHelper}

        def load():
            if not os.path.exists(PACKAGES_JSON):
                return []
            with open(PACKAGES_JSON) as handle:
                return json.load(handle)


        def regenerate(names):
            if not names:
                for path in (PACKAGES_JSON, PACKAGES_NIX):
                    if os.path.exists(path):
                        os.remove(path)
                return
            with open(PACKAGES_JSON, "w") as handle:
                json.dump(names, handle, indent=2)
                handle.write("\n")
            lines = ["{ pkgs, ... }:", "{", "  packages = ["]
            for name in names:
                lines.append("    pkgs." + name)
            lines.append("  ];")
            lines.append("}")
            with open(PACKAGES_NIX, "w") as handle:
                handle.write("\n".join(lines) + "\n")


        def main():
            args = sys.argv[1:]
            if len(args) < 2 or args[0] not in ("add", "remove"):
                print(red("usage: dev pkg <add|remove> <package>..."), file=sys.stderr)
                sys.exit(1)
            action = args[0]
            requested = args[1:]
            invalid = [name for name in requested if not NAME_RE.match(name)]
            if invalid:
                print(
                    red("dev: invalid package name(s): " + ", ".join(invalid) + "!"),
                    file=sys.stderr,
                )
                sys.exit(1)
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            os.makedirs(".dev", exist_ok=True)
            current = load()
            if action == "add":
                names = sorted(set(current) | set(requested))
                regenerate(names)
                for name in requested:
                    if name in current:
                        print(yellow("dev: " + name + " already added"))
                    else:
                        print(green("dev: " + name + " added"))
            else:
                names = [name for name in current if name not in requested]
                regenerate(names)
                for name in requested:
                    if name in current:
                        print(green("dev: " + name + " removed"))
                    else:
                        print(yellow("dev: " + name + " not added"))


        if __name__ == "__main__":
            main()
      '';
    };

    edit = {
      desc = "Edit .dev/devenv.local.nix in $EDITOR";
      text = ''
        import os
        import shlex
        import sys

        STUB = (
            "# https://devenv.sh/reference/options/\n"
            "{ pkgs, lib, inputs, ... }:\n"
            "{\n"
            "  packages = with pkgs; [\n"
            "  ];\n"
            "}\n"
        )


        ${colorHelper}

        def main():
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            editor = os.environ.get("EDITOR")
            if not editor:
                print(red("dev: $EDITOR is not set"), file=sys.stderr)
                sys.exit(1)
            os.makedirs(".dev", exist_ok=True)
            path = os.path.join(".dev", "devenv.local.nix")
            if not os.path.exists(path):
                with open(path, "w") as handle:
                    handle.write(STUB)
            argv = shlex.split(editor) + [path]
            os.execvp(argv[0], argv)


        if __name__ == "__main__":
            main()
      '';
    };

    reset = {
      desc = "Remove all devenv/.dev generated files for a clean state";
      text = ''
        import os
        import shutil
        import subprocess
        import sys

        PATHS = [
            "devenv.nix",
            "devenv.yaml",
            "devenv.lock",
            ".dev",
            ".devenv",
            ".direnv",
        ]


        def is_git_tracked(path):
            return (
                subprocess.run(
                    ["git", "ls-files", "--error-unmatch", path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                ).returncode
                == 0
            )


        def remove(path):
            if not os.path.exists(path) and not os.path.islink(path):
                return False
            if os.path.isdir(path) and not os.path.islink(path):
                shutil.rmtree(path)
            else:
                os.remove(path)
            return True


        ${colorHelper}

        def main():
            removed = [path for path in PATHS if remove(path)]
            if not is_git_tracked(".envrc") and remove(".envrc"):
                removed.append(".envrc")
            if not removed:
                print(yellow("dev: nothing to reset"))
                return
            for path in removed:
                print(green("dev: removed " + path))


        if __name__ == "__main__":
            main()
      '';
    };

    "ignore-devenv" = {
      desc = "Exclude devenv files via .git/info/exclude";
      text = ''
        import os
        import subprocess
        import sys

        ENTRIES = ["devenv.nix", "devenv.yaml", "devenv.lock"]


        ${addGitExcludesHelper}

        ${colorHelper}

        def main():
            add_git_excludes(ENTRIES)
            print(green("dev: excluded devenv.nix, devenv.yaml, devenv.lock via .git/info/exclude"))


        if __name__ == "__main__":
            main()
      '';
    };

    "unignore-devenv" = {
      desc = "Remove devenv files from .git/info/exclude";
      text = ''
        import os
        import subprocess
        import sys

        ENTRIES = {"devenv.nix", "devenv.yaml", "devenv.lock"}


        ${gitExcludePathHelper}

        ${colorHelper}

        def main():
            path = git_exclude_path()
            if not os.path.exists(path):
                print(yellow("dev: nothing to unignore"))
                return
            with open(path) as handle:
                lines = [line.rstrip("\n") for line in handle]
            kept = [line for line in lines if line not in ENTRIES]
            with open(path, "w") as handle:
                for line in kept:
                    handle.write(line + "\n")
            print(green("dev: removed devenv.nix, devenv.yaml, devenv.lock from .git/info/exclude"))


        if __name__ == "__main__":
            main()
      '';
    };
  };

  subScripts = lib.mapAttrs (
    name: sub:
    pkgs.writers.writePython3 "dev-${name}" {
      flakeIgnore = [
        "E501"
        "E231"
        "W503"
      ];
    } sub.text
  ) subcommands;

  dispatcher = pkgs.writeShellScript "dev" ''
    set -eu
    self=$(${pkgs.coreutils}/bin/readlink -f "$0")
    scripts=$(${pkgs.coreutils}/bin/dirname "$self")/../libexec/dev

    list() {
      for f in "$scripts"/dev-*; do
        [ -e "$f" ] || continue
        printf '  %s\n' "''${f##*/dev-}"
      done
    }

    red() {
      if [ -t 2 ] && [ -z "''${NO_COLOR:-}" ] && [ "''${TERM:-}" != "dumb" ]; then
        printf '\033[1;31m%s\033[0m\n' "$1" >&2
      else
        printf '%s\n' "$1" >&2
      fi
    }

    if [ "$#" -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
      echo "usage: dev <command> [args...]"
      echo "commands:"
      list
      exit 0
    fi

    if ! ${pkgs.git}/bin/git rev-parse --git-dir >/dev/null 2>&1; then
      red "dev: not inside a git repository"
      red "dev projects must live in a git-managed repo; run 'git init' first"
      exit 1
    fi

    cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel)"

    cmd="$1"
    shift
    target="$scripts/dev-$cmd"
    if [ ! -x "$target" ]; then
      red "dev: unknown command '$cmd'"
      echo "commands:" >&2
      list >&2
      exit 1
    fi
    exec "$target" "$@"
  '';

  completion = pkgs.writeText "dev.fish" (
    ''
      complete -c dev -f

      set -l subcommands ${lib.concatStringsSep " " (builtins.attrNames subcommands)}

    ''
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: sub:
        ''complete -c dev -n "not __fish_seen_subcommand_from $subcommands" -a ${name} -d "${sub.desc}"''
      ) subcommands
    )
    + ''


      complete -c dev -n "__fish_seen_subcommand_from init" -l force -d "Overwrite an existing devenv.nix"
      complete -c dev -n "__fish_seen_subcommand_from enable" -a "${enableCompletionNames}" -d "Feature"
      complete -c dev -n "__fish_seen_subcommand_from disable" -a "(dev list 2>/dev/null | string match --invert 'dev:*')" -d "Enabled feature"
      complete -c dev -n "__fish_seen_subcommand_from add" -l lang -a "${addCompletionNames}" -d "Language to add the dependency to"
      complete -c dev -n "__fish_seen_subcommand_from pkg" -a "add remove" -d "Action"
    ''
  );

  devPkg = pkgs.runCommand "dev" { } ''
    mkdir -p $out/bin $out/libexec/dev $out/share/fish/vendor_completions.d
    install -m755 ${dispatcher} $out/bin/dev
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: drv: "install -m755 ${drv} $out/libexec/dev/dev-${name}") subScripts
    )}
    install -m644 ${completion} $out/share/fish/vendor_completions.d/dev.fish
  '';
in
{
  name = "devenv";

  group = "dev";
  input = "common";

  description = "devenv and the dev project manager CLI";

  module = {
    enabled = config: {
      nx.common.git.git.globalIgnores = [
        ".devenv*"
        ".dev/"
      ];
    };

    home = config: {
      home.packages = [
        pkgs.devenv
        devPkg
      ];
    };
  };
}
