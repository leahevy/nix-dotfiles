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
  builtinInputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/${self.inputs.nixpkgs.rev}";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/${self.inputs.nixpkgs-unstable.rev}";
    devenv.url = "github:cachix/devenv/${self.inputs.devenv.rev}";
    nixpkgs-python.url = "github:cachix/nixpkgs-python/${self.inputs.nixpkgs-python.rev}";
  };

  devenvNixText = ''
    { pkgs, lib, inputs, ... }:
    {
      cachix.enable = false;
      dotenv.disableHint = true;
      devenv.warnOnNewVersion = false;

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

  devenvTemplate = pkgs.writeText "devenv.nix" devenvNixText;

  devenvNixHash = builtins.hashString "sha256" devenvNixText;

  renderExtraInput =
    name: entry:
    let
      follows = entry.follows or [ ];
    in
    lib.concatStringsSep "\n" (
      [
        "  ${name}:"
        "    url: ${entry.url}"
      ]
      ++ lib.optionals (follows != [ ]) (
        [ "    inputs:" ]
        ++ lib.concatMap (f: [
          "      ${f}:"
          "        follows: ${f}"
        ]) follows
      )
    );

  devenvYamlText =
    extraInputs:
    let
      allInputsYaml = lib.concatStringsSep "\n" (
        lib.mapAttrsToList renderExtraInput (builtinInputs // extraInputs)
      );
    in
    ''
      inputs:
      ${allInputsYaml}
    '';

  devenvYamlTemplate = extraInputs: pkgs.writeText "devenv.yaml" (devenvYamlText extraInputs);

  devenvYamlHash = extraInputs: builtins.hashString "sha256" (devenvYamlText extraInputs);

  envrcTemplate = pkgs.writeText "dev-envrc" ''
    eval "$(devenv direnvrc)"

    watch_dir .dev

    dev_eval_stamp=".devenv/dev-envrc-eval.stamp"
    dev_eval_hash="$(
      for f in .dev/*.nix devenv.nix devenv.yaml devenv.lock; do
        [ -f "$f" ] || continue
        printf '%s\0' "$f"
        cat "$f"
      done | sha256sum | cut -c1-64
    )"
    if [ "$dev_eval_hash" != "$(cat "$dev_eval_stamp" 2>/dev/null)" ]; then
      if devenv shell --refresh-eval-cache -- true; then
        mkdir -p .devenv
        printf '%s' "$dev_eval_hash" > "$dev_eval_stamp"
      fi
    fi

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
      extraFragmentText = ''
        enterShell = '''
          unset NIX_PYTHONPATH
        ''';
      '';
      conflict = "poetry";
      adderName = "python";
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
      extraFragmentText = ''
        enterShell = '''
          unset NIX_PYTHONPATH
        ''';
      '';
      conflict = "uv";
      adderName = "python";
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

  fishShellPath = if self.isModuleEnabled "shell.fish" then "${pkgs.fish}/bin/fish" else null;

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
      extraLines = lib.optionals (language ? extraFragmentText) (
        lib.splitString "\n" (lib.removeSuffix "\n" language.extraFragmentText)
      );
      lines = flattenOptions "" (language.options or { }) ++ extraLines;
      indent = line: if line == "" then "" else "  ${line}";
    in
    ''
      { pkgs, ... }:
      {
      ${lib.concatStringsSep "\n" (map indent lines)}
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
  adderNamesJson = builtins.toJSON (
    lib.mapAttrs (name: language: language.adderName or name) languagesWithAdder
  );
  langsJson = builtins.toJSON languageNames;

  enableCompletionNames = lib.concatStringsSep " " languageNames;
  addCompletionNames = lib.concatStringsSep " " (
    lib.unique (lib.mapAttrsToList (name: language: language.adderName or name) languagesWithAdder)
  );

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

  evalCacheHelper = ''
    STAMP = os.path.join(".devenv", "dev-eval-cache.stamp")


    def _inputs_hash():
        digest = hashlib.sha256()
        paths = sorted(glob.glob(os.path.join(".dev", "*.nix"))) + [
            "devenv.nix",
            "devenv.yaml",
            "devenv.lock",
        ]
        for path in paths:
            if not os.path.isfile(path):
                continue
            digest.update(path.encode())
            with open(path, "rb") as handle:
                digest.update(handle.read())
        return digest.hexdigest()


    def _read_stamp():
        try:
            with open(STAMP) as handle:
                return handle.read()
        except OSError:
            return None


    def _write_stamp(value):
        try:
            os.makedirs(os.path.dirname(STAMP), exist_ok=True)
            with open(STAMP, "w") as handle:
                handle.write(value)
        except OSError:
            pass


    def refresh_eval_cache_if_needed():
        want = _inputs_hash()
        if want == _read_stamp():
            return
        rc = subprocess.run(
            ["devenv", "shell", "--refresh-eval-cache", "--", "true"]
        ).returncode
        if rc != 0:
            sys.exit(rc)
        _write_stamp(want)
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

  configHelper = ''
    CONFIG_PATH = os.path.join(".dev", "config.json")


    def load_config():
        if not os.path.exists(CONFIG_PATH):
            return {}
        with open(CONFIG_PATH) as handle:
            return json.load(handle)


    def save_config(config):
        with open(CONFIG_PATH, "w") as handle:
            json.dump(config, handle, indent=2, sort_keys=True)
            handle.write("\n")
  '';

  fragmentWriteHelper = ''
    def write_fragment(lang, version, dest):
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
  '';

  subcommands = extraInputs: {
    init = {
      desc = "Scaffold a devenv project in the current directory";
      text = ''
        import json
        import os
        import shutil
        import subprocess
        import sys

        DEVENV_TEMPLATE = "${devenvTemplate}"
        DEVENV_YAML_TEMPLATE = "${devenvYamlTemplate extraInputs}"
        ENVRC_TEMPLATE = "${envrcTemplate}"

        FRAGMENTS = ${fragmentsJson}

        VERSION_INSERTS = ${versionInsertsJson}

        EXCLUDES = ["devenv.nix", "devenv.yaml", "devenv.lock"]

        MARKER = os.path.join(".dev", "keep-devenv-tracked")


        ${colorHelper}

        ${addGitExcludesHelper}

        ${configHelper}

        ${fragmentWriteHelper}

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
            write_file(DEVENV_TEMPLATE, "devenv.nix", force or has_devdir)
            write_file(DEVENV_YAML_TEMPLATE, "devenv.yaml", force or has_devdir)
            if not is_git_tracked(".envrc"):
                write_file(ENVRC_TEMPLATE, ".envrc", force)
            os.makedirs(".dev", exist_ok=True)
            config = load_config()
            for lang, version in config.items():
                if lang in FRAGMENTS:
                    write_fragment(lang, version, os.path.join(".dev", lang + ".nix"))
            for name in os.listdir(".dev"):
                if not name.endswith(".nix") or name in ("devenv.local.nix", "packages.nix", "env.nix"):
                    continue
                if name[:-4] not in config:
                    os.remove(os.path.join(".dev", name))
            if not os.path.exists(MARKER):
                add_git_excludes(EXCLUDES)
            if has_devdir:
                print(green("dev: updated devenv.nix, devenv.yaml and enabled features"))
            else:
                print(green("dev: initialised. Run `dev load` (or `dev shell`)."))


        if __name__ == "__main__":
            main()
      '';
    };

    enable = {
      desc = "Enable a feature";
      text = ''
        import json
        import os
        import shutil
        import sys

        FRAGMENTS = ${fragmentsJson}

        CONFLICTS = ${conflictsJson}

        VERSION_INSERTS = ${versionInsertsJson}


        ${colorHelper}

        ${configHelper}

        ${fragmentWriteHelper}

        def main():
            args = sys.argv[1:]
            if not args or args[0] not in FRAGMENTS:
                langs = ", ".join(sorted(FRAGMENTS))
                print(red("usage: dev enable <" + langs + "> [version]"), file=sys.stderr)
                sys.exit(1)
            lang = args[0]
            rest = args[1:]
            version = None
            version_given = False
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
                version_given = True
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            if not os.path.isdir(".dev"):
                print(
                    red(
                        "dev: devenv.nix here is not managed by dev (no .dev/). "
                        "Run `dev init --force` to take it over first!"
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)
            os.makedirs(".dev", exist_ok=True)
            config = load_config()
            already_enabled = lang in config
            if not version_given and already_enabled:
                version = config[lang]
            conflict = CONFLICTS.get(lang)
            if conflict and conflict in config:
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
            dest = os.path.join(".dev", lang + ".nix")
            write_fragment(lang, version, dest)
            config[lang] = version
            save_config(config)
            suffix = " (version " + version + ")" if version else ""
            if already_enabled:
                print(green("dev: " + lang + " updated" + suffix))
            else:
                print(green("dev: enabled " + lang + suffix))


        if __name__ == "__main__":
            main()
      '';
    };

    disable = {
      desc = "Disable a feature";
      text = ''
        import json
        import os
        import sys

        LANGS = ${langsJson}


        ${colorHelper}

        ${configHelper}

        def main():
            args = sys.argv[1:]
            if len(args) != 1 or args[0] not in LANGS:
                print(red("usage: dev disable <" + "|".join(LANGS) + ">"), file=sys.stderr)
                sys.exit(1)
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            if not os.path.isdir(".dev"):
                print(
                    red(
                        "dev: devenv.nix here is not managed by dev (no .dev/). "
                        "Run `dev init --force` to take it over first!"
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)
            lang = args[0]
            dest = os.path.join(".dev", lang + ".nix")
            config = load_config()
            if not os.path.exists(dest) and lang not in config:
                print(yellow("dev: " + lang + " not enabled"))
                return
            if os.path.exists(dest):
                os.remove(dest)
            if lang in config:
                del config[lang]
                save_config(config)
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
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            devdir = ".dev"
            frags = (
                sorted(
                    name[:-4]
                    for name in os.listdir(devdir)
                    if name.endswith(".nix") and name not in ("devenv.local.nix", "packages.nix", "env.nix")
                )
                if os.path.isdir(devdir)
                else []
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
        import glob
        import hashlib
        import os
        import subprocess
        import sys

        FISH_PATH = ${if fishShellPath == null then "None" else "\"${fishShellPath}\""}


        ${colorHelper}

        ${evalCacheHelper}

        def main():
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            refresh_eval_cache_if_needed()
            if FISH_PATH is not None:
                os.execvp("devenv", ["devenv", "shell", "--", FISH_PATH])
            else:
                os.execvp("devenv", ["devenv", "shell"])


        if __name__ == "__main__":
            main()
      '';
    };

    run = {
      desc = "Run a command in the dev shell";
      text = ''
        import glob
        import hashlib
        import os
        import subprocess
        import sys


        ${colorHelper}

        ${evalCacheHelper}

        def main():
            args = sys.argv[1:]
            if not args:
                print(red("usage: dev run <cmd> [args...]"), file=sys.stderr)
                print(red("       dev run --shell '<cmd1> && <cmd2>'"), file=sys.stderr)
                sys.exit(1)
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            if args[0] == "--shell":
                if len(args) != 2:
                    print(red("usage: dev run --shell '<cmd>'"), file=sys.stderr)
                    sys.exit(1)
                cmd = ["bash", "-c", args[1]]
            else:
                cmd = args
            refresh_eval_cache_if_needed()
            os.execvp("devenv", ["devenv", "shell", "--"] + cmd)


        if __name__ == "__main__":
            main()
      '';
    };

    load = {
      desc = "Run 'direnv allow' or 'direnv reload' as appropriate";
      text = ''
        import json
        import os
        import subprocess
        import sys


        ${colorHelper}

        def main():
            if not os.path.isfile(".envrc"):
                print(red("dev: no .envrc here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            result = subprocess.run(
                ["direnv", "status", "--json"],
                stdout=subprocess.PIPE,
                text=True,
                check=True,
            )
            status = json.loads(result.stdout)
            found_rc = status.get("state", {}).get("foundRC")
            allowed = found_rc is not None and found_rc.get("allowed") == 0
            os.execvp("direnv", ["direnv", "reload" if allowed else "allow"])


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

        ADDER_NAMES = ${adderNamesJson}


        ${colorHelper}

        def main():
            args = sys.argv[1:]
            requested = None
            if args[:1] == ["--lang"]:
                if len(args) < 2:
                    print(red("usage: dev add --lang <lang> <pkg> [pkg...]"), file=sys.stderr)
                    sys.exit(1)
                requested = args[1]
                args = args[2:]
                if requested not in ADDER_NAMES.values():
                    print(red("dev: unknown language '" + requested + "'"), file=sys.stderr)
                    sys.exit(1)
            if not args:
                print(red("usage: dev add [--lang <lang>] <pkg> [pkg...]"), file=sys.stderr)
                sys.exit(1)
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            if not os.path.isdir(".dev"):
                print(
                    red(
                        "dev: devenv.nix here is not managed by dev (no .dev/). "
                        "Run `dev init --force` to take it over first!"
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)
            enabled = [
                name for name in ADDERS if os.path.exists(os.path.join(".dev", name + ".nix"))
            ]
            if requested is not None:
                matches = [name for name in enabled if ADDER_NAMES[name] == requested]
                if not matches:
                    print(
                        red(
                            "dev: "
                            + requested
                            + " is not enabled. Run `dev enable "
                            + requested
                            + "` first!"
                        ),
                        file=sys.stderr,
                    )
                    sys.exit(1)
                lang = matches[0]
            else:
                names = sorted(set(ADDER_NAMES[name] for name in enabled))
                if not names:
                    print(
                        red(
                            "dev: no language enabled to add to. Run `dev enable <lang>` first!"
                        ),
                        file=sys.stderr,
                    )
                    sys.exit(1)
                elif len(names) > 1:
                    print(
                        red(
                            "dev: multiple languages enabled ("
                            + ", ".join(names)
                            + "); use --lang to pick one, e.g. `dev add --lang "
                            + names[0]
                            + " "
                            + " ".join(args)
                            + "`"
                        ),
                        file=sys.stderr,
                    )
                    sys.exit(1)
                else:
                    lang = next(name for name in enabled if ADDER_NAMES[name] == names[0])
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
            if not os.path.isdir(".dev"):
                print(
                    red(
                        "dev: devenv.nix here is not managed by dev (no .dev/). "
                        "Run `dev init --force` to take it over first!"
                    ),
                    file=sys.stderr,
                )
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

    env = {
      desc = "Set, unset, or clear environment variables (dev env set/unset/clear)";
      text = ''
        import json
        import os
        import re
        import sys

        ENV_JSON = os.path.join(".dev", "env.json")
        ENV_NIX = os.path.join(".dev", "env.nix")
        NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


        ${colorHelper}

        def nix_str(value):
            escaped = (
                value.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("''${", "\\''${")
                .replace("\n", "\\n")
                .replace("\t", "\\t")
            )
            return "\"" + escaped + "\""


        def load():
            if not os.path.exists(ENV_JSON):
                return {}
            with open(ENV_JSON) as handle:
                return json.load(handle)


        def regenerate(env):
            if not env:
                for path in (ENV_JSON, ENV_NIX):
                    if os.path.exists(path):
                        os.remove(path)
                return
            with open(ENV_JSON, "w") as handle:
                json.dump(env, handle, indent=2, sort_keys=True)
                handle.write("\n")
            lines = ["{ ... }:", "{", "  env = {"]
            for name in sorted(env):
                lines.append("    " + name + " = " + nix_str(env[name]) + ";")
            lines.append("  };")
            lines.append("}")
            with open(ENV_NIX, "w") as handle:
                handle.write("\n".join(lines) + "\n")


        def usage():
            print(red("usage: dev env set <name> <value>"), file=sys.stderr)
            print(red("       dev env set <name>=<value>..."), file=sys.stderr)
            print(red("       dev env unset <name>..."), file=sys.stderr)
            print(red("       dev env clear"), file=sys.stderr)
            sys.exit(1)


        def main():
            args = sys.argv[1:]
            action = args[0] if args else None
            rest = args[1:]
            pairs = []
            names = []
            if action == "set" and rest:
                if "=" in rest[0]:
                    for item in rest:
                        if "=" not in item:
                            usage()
                        name, _, value = item.partition("=")
                        pairs.append((name, value))
                elif len(rest) == 2:
                    pairs.append((rest[0], rest[1]))
                else:
                    usage()
                names = [name for name, _ in pairs]
            elif action == "unset" and rest:
                names = rest
            elif action == "clear" and not rest:
                pass
            else:
                usage()
            invalid = [name for name in names if not NAME_RE.match(name)]
            if invalid:
                print(
                    red("dev: invalid variable name(s): " + ", ".join(invalid) + "!"),
                    file=sys.stderr,
                )
                sys.exit(1)
            if not os.path.isfile("devenv.nix"):
                print(red("dev: no devenv.nix here. Run `dev init` first!"), file=sys.stderr)
                sys.exit(1)
            if not os.path.isdir(".dev"):
                print(
                    red(
                        "dev: devenv.nix here is not managed by dev (no .dev/). "
                        "Run `dev init --force` to take it over first!"
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)
            os.makedirs(".dev", exist_ok=True)
            current = load()
            if action == "set":
                for name, value in pairs:
                    current[name] = value
                    print(green("dev: " + name + " set"))
                regenerate(current)
            elif action == "unset":
                for name in names:
                    if name in current:
                        del current[name]
                        print(green("dev: " + name + " unset"))
                    else:
                        print(yellow("dev: " + name + " not set"))
                regenerate(current)
            else:
                if current:
                    regenerate({})
                    print(green("dev: cleared all environment variables"))
                else:
                    print(yellow("dev: no environment variables set"))


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
            if not os.path.isdir(".dev"):
                print(
                    red(
                        "dev: devenv.nix here is not managed by dev (no .dev/). "
                        "Run `dev init --force` to take it over first!"
                    ),
                    file=sys.stderr,
                )
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
            if os.path.isfile("devenv.nix") and not os.path.isdir(".dev"):
                print(
                    red(
                        "dev: devenv.nix here is not managed by dev (no .dev/). "
                        "Refusing to reset it. Run `dev init --force` to take it over first!"
                    ),
                    file=sys.stderr,
                )
                sys.exit(1)
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

    "unignore-devenv" = {
      desc = "Remove devenv files from .git/info/exclude";
      text = ''
        import os
        import subprocess
        import sys

        ENTRIES = {"devenv.nix", "devenv.yaml", "devenv.lock"}

        MARKER = os.path.join(".dev", "keep-devenv-tracked")


        ${gitExcludePathHelper}

        ${colorHelper}

        def main():
            path = git_exclude_path()
            removed = False
            if os.path.exists(path):
                with open(path) as handle:
                    lines = [line.rstrip("\n") for line in handle]
                kept = [line for line in lines if line not in ENTRIES]
                if kept != lines:
                    with open(path, "w") as handle:
                        for line in kept:
                            handle.write(line + "\n")
                    removed = True
            os.makedirs(".dev", exist_ok=True)
            with open(MARKER, "w"):
                pass
            if removed:
                print(green("dev: removed devenv.nix, devenv.yaml, devenv.lock from .git/info/exclude and marked them to stay tracked"))
            else:
                print(green("dev: marked devenv.nix, devenv.yaml, devenv.lock to stay tracked"))


        if __name__ == "__main__":
            main()
      '';
    };
  };

  subScripts =
    extraInputs:
    lib.mapAttrs (
      name: sub:
      pkgs.writers.writePython3 "dev-${name}" {
        flakeIgnore = [
          "E501"
          "E231"
          "W503"
        ];
      } sub.text
    ) (subcommands extraInputs);

  dispatcher =
    extraInputs:
    pkgs.writeShellScript "dev" ''
      set -eu
      self=$(${pkgs.coreutils}/bin/readlink -f "$0")
      scripts=$(${pkgs.coreutils}/bin/dirname "$self")/../libexec/dev
      devenv_nix_hash="${devenvNixHash}"
      devenv_yaml_hash="${devenvYamlHash extraInputs}"

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

      yellow() {
        if [ -t 2 ] && [ -z "''${NO_COLOR:-}" ] && [ "''${TERM:-}" != "dumb" ]; then
          printf '\033[1;33m%s\033[0m' "$1" >&2
        else
          printf '%s' "$1" >&2
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

      git_root=$(${pkgs.git}/bin/git rev-parse --show-toplevel)
      invocation_dir=$(pwd -P)

      cmd="$1"
      shift
      target="$scripts/dev-$cmd"
      if [ ! -x "$target" ]; then
        red "dev: unknown command '$cmd'"
        echo "commands:" >&2
        list >&2
        exit 1
      fi

      root=""
      search_dir="$invocation_dir"
      while : ; do
        if [ -d "$search_dir/.dev" ]; then
          root="$search_dir"
          break
        fi
        [ "$search_dir" = "$git_root" ] && break
        parent=$(${pkgs.coreutils}/bin/dirname "$search_dir")
        [ "$parent" = "$search_dir" ] && break
        search_dir="$parent"
      done

      if [ "$cmd" = "init" ] && [ "$root" != "$invocation_dir" ] && [ "$invocation_dir" != "$git_root" ] && [ -t 0 ] && [ -t 1 ]; then
        if [ -n "$root" ]; then
          yellow "dev: $root is already a dev project. Create a nested devenv in $invocation_dir instead? [y/N] "
        else
          yellow "dev: create a nested devenv in $invocation_dir instead of the repo root $git_root? [y/N] "
        fi
        reply=""
        read -r reply </dev/tty || true
        case "$reply" in
          [yY]*) root="$invocation_dir" ;;
          *) : ;;
        esac
      fi

      if [ -z "$root" ]; then
        root="$git_root"
      fi

      cd "$root"

      if [ "$cmd" != "init" ] && [ "$cmd" != "list" ] && [ -d .dev ]; then
        stale=0
        if [ -f devenv.nix ]; then
          current_hash=$(${pkgs.coreutils}/bin/sha256sum devenv.nix | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          [ "$current_hash" = "$devenv_nix_hash" ] || stale=1
        fi
        if [ -f devenv.yaml ]; then
          current_hash=$(${pkgs.coreutils}/bin/sha256sum devenv.yaml | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          [ "$current_hash" = "$devenv_yaml_hash" ] || stale=1
        fi
        if [ "$stale" -eq 1 ] && [ -t 0 ] && [ -t 1 ]; then
          yellow "dev: devenv.nix/devenv.yaml differ from the current nx configuration. Run 'dev init' first? [Y/n] "
          reply=""
          if read -r reply </dev/tty; then
            case "$reply" in
              ""|[yY]*) "$scripts/dev-init" ;;
              *) : ;;
            esac
          fi
        fi
      fi

      exec "$target" "$@"
    '';

  completion =
    extraInputs:
    pkgs.writeText "dev.fish" (
      ''
        complete -c dev -f

        set -l subcommands ${lib.concatStringsSep " " (builtins.attrNames (subcommands extraInputs))}

      ''
      + lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: sub:
          ''complete -c dev -n "not __fish_seen_subcommand_from $subcommands" -a ${name} -d "${sub.desc}"''
        ) (subcommands extraInputs)
      )
      + ''


        complete -c dev -n "__fish_seen_subcommand_from init" -l force -d "Overwrite an existing devenv.nix"
        complete -c dev -n "__fish_seen_subcommand_from run" -l shell -d "Run <cmd> via bash -c, allowing shell operators like && or ;"
        complete -c dev -n "__fish_seen_subcommand_from enable" -a "${enableCompletionNames}" -d "Feature"
        complete -c dev -n "__fish_seen_subcommand_from disable" -a "(dev list 2>/dev/null | string match --invert 'dev:*')" -d "Enabled feature"
        complete -c dev -n "__fish_seen_subcommand_from add" -l lang -a "${addCompletionNames}" -d "Language to add the dependency to"
        complete -c dev -n "__fish_seen_subcommand_from pkg" -a "add remove" -d "Action"
        complete -c dev -n "__fish_seen_subcommand_from env" -a "set unset clear" -d "Action"
      ''
    );

  devPkg =
    extraInputs:
    pkgs.runCommand "dev" { } ''
      mkdir -p $out/bin $out/libexec/dev $out/share/fish/vendor_completions.d
      install -m755 ${dispatcher extraInputs} $out/bin/dev
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: drv: "install -m755 ${drv} $out/libexec/dev/dev-${name}") (
          subScripts extraInputs
        )
      )}
      install -m644 ${completion extraInputs} $out/share/fish/vendor_completions.d/dev.fish
    '';
in
{
  name = "devenv";

  group = "dev";
  input = "common";

  description = "devenv and the dev project manager CLI";

  options = {
    extraInputs = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "Flake input URL";
            };
            follows = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Names of this input's own sub-inputs that should follow the top-level input of the same name";
            };
          };
        }
      );
      default = { };
      description = "Extra flake inputs to include in every generated devenv.yaml";
    };
  };

  module = {
    enabled =
      config:
      let
        extraInputs = config.nx.common.dev.devenv.extraInputs;
        reservedNames = lib.attrNames builtinInputs;
        extraNames = lib.attrNames extraInputs;
        validFollowsTargets = reservedNames ++ extraNames;
        invalidFollows = lib.filterAttrs (
          _: entry: !(lib.all (f: builtins.elem f validFollowsTargets) entry.follows)
        ) extraInputs;
      in
      {
        nx.common.git.git.globalIgnores = [
          ".devenv*"
          ".dev/"
        ];

        assertions = [
          {
            assertion = lib.intersectLists extraNames reservedNames == [ ];
            message = "nx.common.dev.devenv.extraInputs uses a reserved input name (${lib.concatStringsSep ", " reservedNames})!";
          }
          {
            assertion = invalidFollows == { };
            message = "nx.common.dev.devenv.extraInputs has a follows value that does not match any known input: ${builtins.toJSON (lib.attrNames invalidFollows)}!";
          }
        ];
      };

    home =
      { config, extraInputs, ... }:
      {
        home.packages = [
          pkgs.devenv
          (devPkg extraInputs)
        ];
      };
  };
}
