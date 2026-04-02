{
  lib,
  scope,
  system,
}:

let
  inherit (lib)
    concatStringsSep
    mapAttrsToList
    filterAttrs
    attrNames
    attrValues
    filter
    any
    all
    imap0
    ;

  inherit (builtins)
    throw
    hasAttr
    getAttr
    elem
    isList
    ;

  constructors = {
    option = description: { inherit description; };

    optionWith = description: argName: type: {
      inherit description;
      argument = {
        name = argName;
        inherit type;
      };
    };

    optionWithDefault = description: argName: type: default: {
      description = "${description} (default: ${default})";
      argument = {
        name = argName;
        inherit type default;
      };
    };

    optionWithEnum = description: argName: values: {
      inherit description;
      argument = {
        name = argName;
        type = "enum";
        inherit values;
      };
    };

    optionRepeatable = description: argName: type: {
      inherit description;
      repeatable = true;
      argument = {
        name = argName;
        inherit type;
      };
    };

    arg = name: description: type: { inherit name description type; };

    argVariadic = name: description: type: {
      inherit name description type;
      variadic = true;
    };
  };

  inherit (constructors)
    option
    optionWith
    optionWithDefault
    optionWithEnum
    optionRepeatable
    arg
    argVariadic
    ;

  sharedOptions = {
    commonDeploymentOptions = {
      offline = option "Run without network access";
      show-trace = option "Show detailed Nix error traces";
      allow-dirty-git = option "Allow proceeding with uncommitted changes";
      skip-verification = option "Skip commit signature verification";
    };

    gitOptions = {
      only-core = option "Run only on core repository";
      only-config = option "Run only on config repository";
    };
  };

  inherit (sharedOptions) commonDeploymentOptions gitOptions;

  validation = rec {
    validTypes = [
      "string"
      "int"
      "filepath"
      "dirpath"
      "enum"
      "gitBranch"
      "modulePath"
      "nixVersion"
    ];

    validScopes = [
      "integrated"
      "standalone"
      "both"
    ];

    validSystems = [
      "linux"
      "darwin"
      "both"
    ];

    allowedCommandFields = [
      "description"
      "options"
      "arguments"
      "subcommands"
      "completeFiles"
      "scope"
      "system"
      "group"
    ];

    allowedOptionFields = [
      "description"
      "short"
      "argument"
      "repeatable"
      "scope"
      "system"
    ];

    allowedOptionValueFields = [
      "name"
      "type"
      "values"
      "default"
    ];

    allowedArgumentFields = [
      "name"
      "description"
      "type"
      "values"
      "required"
      "variadic"
      "scope"
      "system"
    ];

    assertKnownFields =
      allowed: obj: path:
      let
        unknown = filter (k: !(elem k allowed)) (attrNames obj);
      in
      if unknown != [ ] then
        throw "${path}: unknown fields [${concatStringsSep ", " unknown}], allowed: [${concatStringsSep ", " allowed}]"
      else
        true;

    assertRequiredFields =
      required: obj: path:
      let
        missing = filter (k: !(hasAttr k obj)) required;
      in
      if missing != [ ] then
        throw "${path}: missing required fields [${concatStringsSep ", " missing}]"
      else
        true;

    assertFieldEnum =
      field: valid: obj: path:
      if hasAttr field obj && !(elem (getAttr field obj) valid) then
        throw "${path}.${field}: invalid value '${getAttr field obj}', must be one of [${concatStringsSep ", " valid}]"
      else
        true;

    assertValidOptionValue =
      path: ov:
      assertKnownFields allowedOptionValueFields ov path
      && assertRequiredFields [ "name" "type" ] ov path
      && assertFieldEnum "type" validTypes ov path
      && (
        if ov.type == "enum" then
          if !(ov ? values) then
            throw "${path}: enum type requires 'values' field"
          else if !(isList ov.values) then
            throw "${path}.values: must be a list"
          else
            true
        else
          true
      );

    assertValidOption =
      path: opt:
      assertKnownFields allowedOptionFields opt path
      && assertRequiredFields [ "description" ] opt path
      && assertFieldEnum "scope" validScopes opt path
      && assertFieldEnum "system" validSystems opt path
      && (if opt ? argument then assertValidOptionValue "${path}.argument" opt.argument else true);

    assertValidArgument =
      path: a:
      assertKnownFields allowedArgumentFields a path
      && assertRequiredFields [ "name" "description" "type" ] a path
      && assertFieldEnum "type" validTypes a path
      && assertFieldEnum "scope" validScopes a path
      && assertFieldEnum "system" validSystems a path
      && (
        if (a.type or "") == "enum" then
          if !(a ? values) then
            throw "${path}: enum type requires 'values' field"
          else if !(isList a.values) then
            throw "${path}.values: must be a list"
          else
            true
        else
          true
      );

    allowedSubcommandFields = filter (f: f != "group") allowedCommandFields;

    assertValidSubcommand =
      path: cmd:
      assertKnownFields allowedSubcommandFields cmd path
      && assertRequiredFields [ "description" ] cmd path
      && assertFieldEnum "scope" validScopes cmd path
      && assertFieldEnum "system" validSystems cmd path
      && all (x: x) (
        mapAttrsToList (n: o: assertValidOption "${path}.options.${n}" o) (cmd.options or { })
      )
      && all (x: x) (
        imap0 (i: a: assertValidArgument "${path}.arguments[${toString i}]" a) (cmd.arguments or [ ])
      )
      && all (x: x) (
        mapAttrsToList (n: s: assertValidSubcommand "${path}.subcommands.${n}" s) (cmd.subcommands or { })
      );

    assertValidTopLevelSubcommand =
      path: cmd:
      assertKnownFields allowedCommandFields cmd path
      && assertRequiredFields [ "description" ] cmd path
      && assertFieldEnum "scope" validScopes cmd path
      && assertFieldEnum "system" validSystems cmd path
      && all (x: x) (
        mapAttrsToList (n: o: assertValidOption "${path}.options.${n}" o) (cmd.options or { })
      )
      && all (x: x) (
        imap0 (i: a: assertValidArgument "${path}.arguments[${toString i}]" a) (cmd.arguments or [ ])
      )
      && all (x: x) (
        mapAttrsToList (n: s: assertValidSubcommand "${path}.subcommands.${n}" s) (cmd.subcommands or { })
      );

    assertValidCommand =
      path: cmd:
      assertKnownFields allowedCommandFields cmd path
      && assertRequiredFields [ "description" ] cmd path
      && all (x: x) (
        mapAttrsToList (n: s: assertValidTopLevelSubcommand "${path}.subcommands.${n}" s) (
          cmd.subcommands or { }
        )
      );

    assertValidGroups =
      path: cmd: validGroupIds:
      let
        checkSubcommand =
          subPath: subCmd:
          (
            if subCmd ? group then
              if !(elem subCmd.group validGroupIds) then
                throw "${subPath}: invalid group '${subCmd.group}', must be one of [${concatStringsSep ", " validGroupIds}]"
              else
                true
            else
              true
          )
          && all (x: x) (
            mapAttrsToList (n: s: checkSubcommand "${subPath}.subcommands.${n}" s) (subCmd.subcommands or { })
          );
      in
      all (x: x) (
        mapAttrsToList (n: s: checkSubcommand "${path}.subcommands.${n}" s) (cmd.subcommands or { })
      );

    assertValidGroupStructure =
      groupList:
      all (x: x) (
        imap0 (
          i: g:
          let
            path = "groups[${toString i}]";
          in
          assertRequiredFields [ "id" "label" ] g path && assertKnownFields [ "id" "label" ] g path
        ) groupList
      );

    assertUniqueShortFlags =
      path: cmd:
      let
        collectShorts =
          prefix: c:
          let
            optShorts = mapAttrsToList (
              n: o:
              if o ? short then
                {
                  name = "${prefix}.${n}";
                  short = o.short;
                }
              else
                null
            ) (c.options or { });
            subShorts = builtins.concatMap (
              name: collectShorts "${prefix}.subcommands.${name}" (c.subcommands.${name})
            ) (attrNames (c.subcommands or { }));
          in
          (filter (x: x != null) optShorts) ++ subShorts;

        allShorts = collectShorts path cmd;
        shortFlags = map (x: x.short) allShorts;

        findDuplicates =
          list:
          let
            count = f: builtins.length (filter (x: x == f) list);
            seen =
              s: xs:
              if xs == [ ] then
                [ ]
              else
                let
                  h = builtins.head xs;
                  t = builtins.tail xs;
                in
                if elem h s then
                  seen s t
                else if count h > 1 then
                  [ h ] ++ seen (s ++ [ h ]) t
                else
                  seen (s ++ [ h ]) t;
          in
          seen [ ] list;

        dups = findDuplicates shortFlags;
      in
      if dups != [ ] then
        let
          dupInfo = concatStringsSep ", " (
            map (
              d:
              let
                locations = map (x: x.name) (filter (x: x.short == d) allShorts);
              in
              "-${d} (used in: ${concatStringsSep ", " locations})"
            ) dups
          );
        in
        throw "${path}: duplicate short flags found: ${dupInfo}"
      else
        true;
  };

  inherit (validation)
    assertValidCommand
    assertValidGroups
    assertValidGroupStructure
    assertUniqueShortFlags
    ;

  name = "nx";
  version = "0.0.1";
  gitRepoPath = "~/.config/nx/nxcore";

  groups = [
    {
      id = "configuration";
      label = "Configuration";
    }
    {
      id = "switch";
      label = "Switch Commands";
    }
    {
      id = "evaluation";
      label = "Evaluation";
    }
    {
      id = "modules";
      label = "Specializations & Modules";
    }
    {
      id = "folder";
      label = "Folder Commands";
    }
    {
      id = "git";
      label = "Git Commands";
    }
  ];

  nx = {
    description = "Manage home-manager or NixOS system";
    options = {
      help = {
        description = "Show help message";
        short = "h";
      };
      version = {
        description = "Show version information";
      };
    };
    subcommands = {
      profile = {
        description = "Configure to use profile";
        group = "configuration";
        subcommands = {
          user = {
            description = "Navigate to user directory or edit user config";
            scope = "integrated";
            subcommands = {
              edit = {
                description = "Edit integrated user configuration file";
              };
            };
          };
          edit = {
            description = "Edit active profile configuration file";
          };
          select = {
            description = "Set active profile name";
            arguments = [ (arg "profile" "Profile name" "string") ];
          };
          reset = {
            description = "Reset to default profile";
          };
          help = {
            description = "Show help message";
          };
        };
      };

      build = {
        description = "Test build configuration without deploying";
        group = "switch";
        options = {
          timeout = optionWithDefault "Set timeout in seconds" "seconds" "int" "7200";
          dry-run = option "Test build without actual building";
          offline = option "Build without network access";
          diff = option "Compare built config with current active system";
          show-trace = option "Show detailed Nix error traces";
          skip-verification = option "Skip commit signature verification";
          raw = option "Use raw log format";
        };
      };

      sync = {
        description = "Sync/deploy the system state";
        group = "switch";
        options = commonDeploymentOptions;
      };

      gc = {
        description = "Run the garbage collection";
        group = "switch";
      };
      update = {
        description = "Update the flake in git (without switching)";
        group = "switch";
      };

      dist-upgrade = {
        description = "Bump NixOS version and migrate packages";
        group = "switch";
        scope = "integrated";
        arguments = [ (arg "version" "Target NixOS version (XX.XX)" "nixVersion") ];
      };

      brew = {
        description = "Sync Homebrew packages";
        group = "switch";
        system = "darwin";
      };

      dry = {
        description = "Test configuration without deploying";
        group = "switch";
        scope = "integrated";
        options = commonDeploymentOptions;
      };
      test = {
        description = "Activate without adding to bootloader";
        group = "switch";
        scope = "integrated";
        options = commonDeploymentOptions;
      };
      boot = {
        description = "Add to bootloader without switching";
        group = "switch";
        scope = "integrated";
        options = commonDeploymentOptions;
      };
      rollback = {
        description = "Rollback to previous configuration";
        group = "switch";
        scope = "integrated";
        options = {
          allow-dirty-git = option "Allow proceeding with uncommitted changes";
        };
      };
      impermanence = {
        description = "Manage ephemeral root filesystems";
        group = "switch";
        scope = "integrated";
        subcommands = {
          check = {
            description = "List files/directories in ephemeral root";
            options = {
              home = option "Show only paths under /home";
              system = option "Show only system paths";
              filter = optionRepeatable "Filter results by keyword" "keyword" "string";
            };
          };
          diff = {
            description = "Compare historical impermanence check logs";
            options = {
              range = optionWith "Compare with Nth previous log" "range" "int";
              home = option "Compare only home check logs";
              system = option "Compare only system check logs";
            };
          };
          logs = {
            description = "Show impermanence rollback logs";
          };
          help = {
            description = "Show help message";
          };
        };
      };

      news = {
        description = "Show recent news";
        group = "switch";
        scope = "standalone";
      };

      eval = {
        description = "Evaluate a flake path with config override";
        group = "evaluation";
        options = {
          home = option "Evaluate in home-manager context";
        };
        arguments = [ (arg "path" "Nix eval path" "string") ];
      };
      package = {
        description = "Get store path for package(s)";
        group = "evaluation";
        options = {
          unstable = option "Use nixpkgs-unstable instead of nixpkgs";
        };
        arguments = [ (argVariadic "packages" "Package name(s)" "string") ];
      };
      version = {
        description = "Show the current NixOS version";
        group = "evaluation";
      };

      config = {
        description = "Open a shell in the config directory";
        group = "folder";
      };
      core = {
        description = "Open a shell in the core directory";
        group = "folder";
      };
      format = {
        description = "Format directories with treefmt";
        group = "folder";
      };
      exec = {
        description = "Run any command in the directory";
        group = "folder";
        completeFiles = true;
      };

      spec = {
        description = "Manage specializations";
        group = "modules";
        options = {
          home = option "Operate on home-manager specializations";
        };
        subcommands = {
          list = {
            description = "List all available specializations";
          };
          switch = {
            description = "Switch to specified specialization";
            arguments = [ (arg "name" "Specialization name" "string") ];
          };
          reset = {
            description = "Reset to base configuration";
          };
        };
      };

      modules = {
        description = "Manage and inspect NX modules";
        group = "modules";
        subcommands = {
          list = {
            description = "List available modules";
            options = {
              active = option "Show only active modules";
              inactive = option "Show only inactive modules";
              profile = optionWith "Use specific profile" "profile" "string";
              nixos = option "Force NixOS mode";
              standalone = option "Force standalone mode";
            };
          };
          config = {
            description = "Show complete active configuration";
            options = {
              profile = optionWith "Use specific profile" "profile" "string";
              arch = optionWithEnum "Use specific architecture" "architecture" [
                "x86_64-linux"
                "aarch64-linux"
                "x86_64-darwin"
                "aarch64-darwin"
              ];
              nixos = option "Force NixOS mode";
              standalone = option "Force standalone mode";
            };
          };
          info = {
            description = "Show detailed module information";
            arguments = [ (arg "module" "Module name (INPUT.GROUP.MODULE)" "modulePath") ];
          };
          edit = {
            description = "Open module file in editor, creates if needed";
            arguments = [ (arg "module" "Module name (INPUT.GROUP.MODULE)" "modulePath") ];
          };
          help = {
            description = "Show help message";
          };
        };
      };

      log = {
        description = "Run git log command";
        group = "git";
        options = gitOptions;
      };
      head = {
        description = "Run git show HEAD command";
        group = "git";
        options = gitOptions;
      };
      diff = {
        description = "Run git diff command";
        group = "git";
        options = gitOptions;
      };
      diffc = {
        description = "Run git diff --cached command";
        group = "git";
        options = gitOptions;
      };
      status = {
        description = "Run git status command";
        group = "git";
        options = gitOptions;
      };
      commit = {
        description = "Run git commit command";
        group = "git";
        options = gitOptions;
        arguments = [ (arg "message" "Commit message" "string") ];
      };
      pull = {
        description = "Run git pull command";
        group = "git";
        options = gitOptions;
      };
      push = {
        description = "Run git push command";
        group = "git";
        options = gitOptions;
      };
      add = {
        description = "Run git add command";
        group = "git";
        options = gitOptions;
      };
      addp = {
        description = "Run git add --patch command";
        group = "git";
        options = gitOptions;
      };
      stash = {
        description = "Run git stash command";
        group = "git";
        options = gitOptions;
      };
      switch-branch = {
        description = "Switch git branches with safety checks";
        group = "git";
        options = gitOptions;
        arguments = [ (arg "branch" "Branch to switch to" "gitBranch") ];
      };
    };
  };

  helpers = rec {
    getOpts = cmd: cmd.options or { };
    getSubs = cmd: cmd.subcommands or { };
    getArgs = cmd: cmd.arguments or [ ];
    hasOpts = cmd: (getOpts cmd) != { };
    hasSubs = cmd: (getSubs cmd) != { };
    hasContent = cmd: hasOpts cmd || hasSubs cmd || (getArgs cmd) != [ ];

    ind = n: s: concatStringsSep "" (builtins.genList (_: "    ") n) + s;

    filterCmds =
      cmds:
      filterAttrs (
        _: cmd:
        let
          s = cmd.scope or "both";
          p = cmd.system or "both";
        in
        (s == "both" || s == scope) && (p == "both" || p == system)
      ) cmds;

    optArgEnumValues =
      opt:
      let
        a = opt.argument or null;
      in
      if a != null && (a.type or "string") == "enum" && (a.values or null) != null then
        concatStringsSep " " a.values
      else
        null;

    allWords =
      cmd:
      concatStringsSep " " ((map (n: "--${n}") (attrNames (getOpts cmd))) ++ (attrNames (getSubs cmd)));

    filterTree =
      cmd:
      cmd
      // {
        subcommands = builtins.mapAttrs (_: filterTree) (filterCmds (getSubs cmd));
        options = filterCmds (getOpts cmd);
        arguments = filter (
          a:
          let
            s = a.scope or "both";
            p = a.system or "both";
          in
          (s == "both" || s == scope) && (p == "both" || p == system)
        ) (getArgs cmd);
      };

    compactMapAttrs = f: attrs: concatStringsSep "\n" (filter (s: s != "") (mapAttrsToList f attrs));

    bashOptArgCase =
      optName: opt:
      if (opt.argument or null) == null then
        ""
      else
        let
          ev = optArgEnumValues opt;
        in
        if ev != null then
          concatStringsSep "\n" [
            (ind 5 "--${optName})")
            (ind 6 "COMPREPLY=($(compgen -W \"${ev}\" -- \"\${cur}\"))")
            (ind 6 ";;")
          ]
        else
          concatStringsSep "\n" [
            (ind 5 "--${optName})")
            (ind 6 "COMPREPLY=()")
            (ind 6 ";;")
          ];
  };
  inherit (helpers)
    getOpts
    getSubs
    getArgs
    hasOpts
    hasSubs
    hasContent
    optArgEnumValues
    allWords
    compactMapAttrs
    bashOptArgCase
    ind
    filterTree
    ;

  nxValidated =
    assert assertValidGroupStructure groups;
    assert assertValidCommand "nx" nx;
    assert assertValidGroups "nx" nx (map (g: g.id) groups);
    assert assertUniqueShortFlags "nx" nx;
    filterTree nx;

  outputs = {
    bash =
      let
        subs = getSubs nxValidated;
        opts = getOpts nxValidated;
        allSubsStr = concatStringsSep " " (attrNames subs);

        topLevelOpts = concatStringsSep " " (
          (map (n: "--${n}") (attrNames opts))
          ++ (filter (s: s != "") (mapAttrsToList (_: o: if o ? short then "-${o.short}" else "") opts))
        );

        level2Cases = compactMapAttrs (
          name: cmd:
          let
            w = allWords cmd;
          in
          if w == "" then
            ""
          else
            concatStringsSep "\n" [
              (ind 3 "${name})")
              (ind 4 "COMPREPLY=($(compgen -W \"${w}\" -- \"\${cur}\"))")
              (ind 4 ";;")
            ]
        ) subs;

        level3Cases = compactMapAttrs (
          cmdName: cmd:
          let
            cmdSubs = getSubs cmd;
            cmdOpts = getOpts cmd;

            subCases = compactMapAttrs (
              subName: sub:
              let
                w = allWords sub;
              in
              if w != "" then
                concatStringsSep "\n" [
                  (ind 5 "${subName})")
                  (ind 6 "COMPREPLY=($(compgen -W \"${w}\" -- \"\${cur}\"))")
                  (ind 6 ";;")
                ]
              else if (getArgs sub) != [ ] then
                concatStringsSep "\n" [
                  (ind 5 "${subName})")
                  (ind 6 "COMPREPLY=()")
                  (ind 6 ";;")
                ]
              else
                ""
            ) cmdSubs;

            optArgCases = compactMapAttrs bashOptArgCase cmdOpts;

            innerCases = filter (s: s != "") [
              subCases
              optArgCases
            ];
          in
          if innerCases == [ ] then
            ""
          else
            concatStringsSep "\n" [
              (ind 3 "${cmdName})")
              (ind 4 "case \"$prev\" in")
              (concatStringsSep "\n" innerCases)
              (ind 4 "esac")
              (ind 4 ";;")
            ]
        ) subs;

        deepCmds = filterAttrs (
          _: cmd:
          let
            cs = getSubs cmd;
          in
          cs != { } && any hasOpts (attrValues cs)
        ) subs;

        level4Sections = concatStringsSep "\n" (
          mapAttrsToList (
            cmdName: cmd:
            let
              cmdSubs = filterAttrs (_: sub: hasOpts sub) (getSubs cmd);
              cases = concatStringsSep "\n" (
                mapAttrsToList (
                  subName: sub:
                  let
                    opts = getOpts sub;
                    allOptWords = concatStringsSep " " (map (n: "--${n}") (attrNames opts));
                    argCases = compactMapAttrs bashOptArgCase opts;
                  in
                  concatStringsSep "\n" (
                    [
                      (ind 3 "${subName})")
                      (ind 4 "case \"$prev\" in")
                    ]
                    ++ (if argCases != "" then [ argCases ] else [ ])
                    ++ [
                      (ind 5 "*)")
                      (ind 6 "COMPREPLY=($(compgen -W \"${allOptWords}\" -- \"\${cur}\"))")
                      (ind 6 ";;")
                      (ind 4 "esac")
                      (ind 4 ";;")
                    ]
                  )
                ) cmdSubs
              );
            in
            concatStringsSep "\n" [
              (ind 1 "elif [[ \"\${COMP_WORDS[1]}\" == \"${cmdName}\" ]] && [[ \${COMP_CWORD} -eq 4 ]]; then")
              (ind 2 "case \"\${COMP_WORDS[2]}\" in")
              cases
              (ind 2 "esac")
            ]
          ) deepCmds
        );

      in
      ''
        _complete_${name}() {
            local cur="''${COMP_WORDS[COMP_CWORD]}"
            local prev="''${COMP_WORDS[COMP_CWORD-1]}"
            local commands="${allSubsStr}"

            if [[ ''${COMP_CWORD} -eq 1 ]]; then
                COMPREPLY=($(compgen -W "''${commands} ${topLevelOpts}" -- "''${cur}"))
            elif [[ ''${COMP_CWORD} -eq 2 ]]; then
                case "$prev" in
        ${level2Cases}
                esac
            elif [[ ''${COMP_CWORD} -eq 3 ]]; then
                case "''${COMP_WORDS[1]}" in
        ${level3Cases}
                esac
        ${level4Sections}
            fi
        }

        complete -F _complete_${name} ${name}
      '';

    zsh =
      let
        subs = getSubs nxValidated;

        cmdDescs = concatStringsSep "\n" (
          mapAttrsToList (name: cmd: ind 4 "'${name}:${cmd.description}'") subs
        );

        zshOptSpec =
          name: opt:
          let
            rep = if opt.repeatable or false then "*" else "";
            a = opt.argument or null;
            argPart =
              if a == null then
                ""
              else
                let
                  ev = optArgEnumValues opt;
                  t = a.type or "string";
                in
                if ev != null then
                  ":${a.name}:(${ev})"
                else if t == "filepath" then
                  ":${a.name}:_files"
                else if t == "dirpath" then
                  ":${a.name}:_directories"
                else
                  ":${a.name}:";
          in
          "'${rep}--${name}[${opt.description}]${argPart}'";

        zshJoinSpecs = indent: specs: concatStringsSep " \\\n${indent}" specs;

        zshArgSpecs =
          args:
          map (
            a:
            let
              v = if a.variadic or false then "*" else "";
              t = a.type or "string";
              action =
                if t == "enum" then
                  "(${concatStringsSep " " (a.values or [ ])})"
                else if t == "filepath" then
                  "_files"
                else if t == "dirpath" then
                  "_directories"
                else
                  "_message \"${a.name}\"";
            in
            "'${v}:${a.description}:${action}'"
          ) args;

        zshCmdCase =
          cmdName: cmd:
          let
            opts = getOpts cmd;
            cmdSubs = getSubs cmd;
            args = getArgs cmd;
            optSpecs = mapAttrsToList zshOptSpec opts;
            argSpecs = zshArgSpecs args;
            allSpecs = optSpecs ++ argSpecs;
          in
          if !hasContent cmd then
            null

          else if cmdSubs == { } then
            concatStringsSep "\n" [
              (ind 4 "${cmdName})")
              (ind 5 "_arguments \\")
              (ind 6 (zshJoinSpecs (ind 6 "") allSpecs))
              (ind 5 ";;")
            ]

          else
            let
              subDescs = concatStringsSep "\n" (
                mapAttrsToList (sn: sc: ind 7 "'${sn}:${sc.description}'") cmdSubs
              );

              pos2 =
                if opts == { } then
                  concatStringsSep "\n" [
                    (ind 6 "2)")
                    (ind 7 "local subcommands=(")
                    subDescs
                    (ind 7 ")")
                    (ind 7 "_describe '${cmdName} subcommands' subcommands")
                    (ind 7 ";;")
                  ]
                else
                  let
                    subNameList = concatStringsSep " " (attrNames cmdSubs);
                  in
                  concatStringsSep "\n" [
                    (ind 6 "2)")
                    (ind 7 "_arguments \\")
                    (ind 8 (zshJoinSpecs (ind 8 "") (optSpecs ++ [ "'1: :(${subNameList})'" ])))
                    (ind 7 ";;")
                  ];

              subsNeedingL3 = filterAttrs (_: sub: hasOpts sub || hasSubs sub || (getArgs sub) != [ ]) cmdSubs;

              pos3 =
                if subsNeedingL3 == { } then
                  ""
                else
                  let
                    innerCases = compactMapAttrs (
                      sn: sub:
                      let
                        so = getOpts sub;
                        ss = getSubs sub;
                        sa = getArgs sub;
                      in
                      if so != { } then
                        let
                          specs = (mapAttrsToList zshOptSpec so) ++ (zshArgSpecs sa);
                        in
                        concatStringsSep "\n" [
                          (ind 8 "${sn})")
                          (ind 9 "_arguments \\")
                          (ind 10 (zshJoinSpecs (ind 10 "") specs))
                          (ind 9 ";;")
                        ]
                      else if ss != { } then
                        concatStringsSep "\n" [
                          (ind 8 "${sn})")
                          (ind 9 "_arguments '1: :(${concatStringsSep " " (attrNames ss)})'")
                          (ind 9 ";;")
                        ]
                      else if sa != [ ] then
                        let
                          a = builtins.head sa;
                        in
                        concatStringsSep "\n" [
                          (ind 8 "${sn})")
                          (ind 9 "_message \"${a.name}\"")
                          (ind 9 ";;")
                        ]
                      else
                        ""
                    ) subsNeedingL3;
                  in
                  concatStringsSep "\n" [
                    (ind 6 "3)")
                    (ind 7 "case \"$line[2]\" in")
                    innerCases
                    (ind 7 "esac")
                    (ind 7 ";;")
                  ];

            in
            concatStringsSep "\n" (
              [
                (ind 4 "${cmdName})")
                (ind 5 "case $CURRENT in")
                pos2
              ]
              ++ (if pos3 != "" then [ pos3 ] else [ ])
              ++ [
                (ind 5 "esac")
                (ind 5 ";;")
              ]
            );

        cmdCases = concatStringsSep "\n" (filter (s: s != null) (mapAttrsToList zshCmdCase subs));

        topLevelOptsZsh =
          let
            opts = getOpts nxValidated;
            formatTopOpt =
              optName: opt:
              let
                short = if opt ? short then "-${opt.short}" else null;
                long = "--${optName}";
                mutual = if short != null then "(${short} ${long})" else "(${long})";
                flags = if short != null then "'{${short},${long}}'" else "${long}";
              in
              "'${mutual}${flags}[${opt.description}]'";
          in
          concatStringsSep " \\\n                " (mapAttrsToList formatTopOpt opts);

      in
      ''
        _${name}() {
            local context state line

            _arguments \
                ${topLevelOptsZsh} \
                '1: :->commands' \
                '*::arg:->args'

            case $state in
                commands)
                    local commands=(
        ${cmdDescs}
                    )
                    _describe 'commands' commands
                    ;;
                args)
                    case $line[1] in
        ${cmdCases}
                    esac
                    ;;
            esac
        }

        compdef _${name} ${name}
      '';

    fish =
      let
        subs = getSubs nxValidated;
        allSubsList = attrNames subs;
        allSubsStr = concatStringsSep " " allSubsList;

        fileCmds = attrNames (filterAttrs (_: cmd: cmd.completeFiles or false) subs);
        noFileCond =
          if fileCmds == [ ] then
            ""
          else
            " -n \"not __fish_seen_subcommand_from ${concatStringsSep " " fileCmds}\"";

        topLevel = concatStringsSep "\n" (
          [
            "complete -c ${name}${noFileCond} -f"
            ""
          ]
          ++ (mapAttrsToList (
            cmdName: cmd:
            "complete -c ${name} -n \"not __fish_seen_subcommand_from ${allSubsStr}\" -a \"${cmdName}\" -d \"${cmd.description}\""
          ) subs)
        );

        fishCmdSection =
          cmdName: cmd:
          let
            opts = getOpts cmd;
            cmdSubs = getSubs cmd;
            subList = attrNames cmdSubs;
            subStr = concatStringsSep " " subList;
            isSubs = cmdSubs != { };

            baseCond = "__fish_seen_subcommand_from ${cmdName}";
            subGuard = if isSubs then " -n \"not __fish_seen_subcommand_from ${subStr}\"" else "";

            fishOptLine =
              condFlags: oName: opt:
              let
                a = opt.argument or null;
                rFlag = if a != null then " -r" else "";
                ev = optArgEnumValues opt;
                aFlag = if ev != null then " -a \"${ev}\"" else "";
                t = if a != null then (a.type or "string") else "";
                fFlag = if a != null && t != "filepath" && t != "dirpath" then " -f" else "";
              in
              "complete -c ${name}${condFlags} -l ${oName} -d \"${opt.description}\"${rFlag}${fFlag}${aFlag}";

            cmdCondFlags = " -n \"${baseCond}\"${subGuard}";
            optLines = mapAttrsToList (fishOptLine cmdCondFlags) opts;

            subLines = mapAttrsToList (
              sn: sc: "complete -c ${name}${cmdCondFlags} -a \"${sn}\" -d \"${sc.description}\""
            ) cmdSubs;

            perSubLines = builtins.concatMap (
              sn:
              let
                sub = cmdSubs.${sn};
                subCondFlags = " -n \"${baseCond}\" -n \"__fish_seen_subcommand_from ${sn}\"";
                subSubs = getSubs sub;
                subSubList = attrNames subSubs;
                subSubStr = concatStringsSep " " subSubList;
                subSubGuard = if subSubs != { } then " -n \"not __fish_seen_subcommand_from ${subSubStr}\"" else "";

                soLines = mapAttrsToList (fishOptLine subCondFlags) (getOpts sub);

                ssLines = mapAttrsToList (
                  ssn: ssc: "complete -c ${name}${subCondFlags}${subSubGuard} -a \"${ssn}\" -d \"${ssc.description}\""
                ) subSubs;

                ssoLines = builtins.concatMap (
                  ssn:
                  let
                    ssCondFlags = subCondFlags + " -n \"__fish_seen_subcommand_from ${ssn}\"";
                  in
                  mapAttrsToList (fishOptLine ssCondFlags) (getOpts subSubs.${ssn})
                ) subSubList;

                saLines = builtins.concatMap (
                  a:
                  if a.type == "gitBranch" then
                    [
                      "complete -c ${name}${subCondFlags}${subSubGuard} -a \"(__${name}_git_branches)\" -d \"${a.description}\""
                    ]
                  else if a.type == "enum" then
                    [
                      "complete -c ${name}${subCondFlags}${subSubGuard} -a \"${
                        concatStringsSep " " (a.values or [ ])
                      }\" -d \"${a.description}\""
                    ]
                  else
                    [ ]
                ) (getArgs sub);
              in
              soLines ++ ssLines ++ ssoLines ++ saLines
            ) subList;

            argLines = builtins.concatMap (
              a:
              if a.type == "gitBranch" then
                [
                  "complete -c ${name}${cmdCondFlags} -a \"(__${name}_git_branches)\" -d \"${a.description}\""
                ]
              else if a.type == "enum" then
                [
                  "complete -c ${name}${cmdCondFlags} -a \"${
                    concatStringsSep " " (a.values or [ ])
                  }\" -d \"${a.description}\""
                ]
              else
                [ ]
            ) (getArgs cmd);

            allLines = optLines ++ subLines ++ perSubLines ++ argLines;
          in
          if allLines == [ ] then "" else "\n# ${cmdName}\n" + concatStringsSep "\n" allLines;

        perCmdSections = concatStringsSep "" (mapAttrsToList fishCmdSection subs);

        hasGitBranchType =
          let
            checkArgs = args: any (a: (a.type or "") == "gitBranch") args;
            checkCmd = cmd: checkArgs (getArgs cmd) || any checkCmd (attrValues (getSubs cmd));
          in
          checkCmd nxValidated;

        branchHelper =
          if hasGitBranchType then
            ''

              function __${name}_git_branches
                  if test -d ${gitRepoPath}/.git
                      git -C ${gitRepoPath} branch --format='%(refname:short)' 2>/dev/null
                  end
              end''
          else
            "";

        globalOpts =
          let
            opts = getOpts nxValidated;
            formatGlobalOpt =
              optName: opt:
              let
                shortFlag = if opt ? short then " -s ${opt.short}" else "";
              in
              "complete -c ${name} -l ${optName}${shortFlag} -d \"${opt.description}\"";
          in
          "\n" + concatStringsSep "\n" (mapAttrsToList formatGlobalOpt opts);

      in
      ''
        ${topLevel}
        ${perCmdSections}
        ${branchHelper}
        ${globalOpts}
      '';

    help =
      let
        subs = getSubs nxValidated;
        opts = getOpts nxValidated;

        cmdsByGroup = id: filterAttrs (_: cmd: (cmd.group or "") == id) subs;

        formatCmdName =
          name: cmd:
          let
            args = getArgs cmd;
            argNames = map (a: if a ? required && !a.required then "[${a.name}]" else "<${a.name}>") args;
            argStr = if argNames == [ ] then "" else " ${concatStringsSep " " argNames}";
          in
          "${name}${argStr}";

        maxCmdLength =
          let
            lengths = map builtins.stringLength (mapAttrsToList (name: cmd: formatCmdName name cmd) subs);
          in
          if lengths == [ ] then 16 else builtins.foldl' (max: len: if len > max then len else max) 0 lengths;

        paddingWidth = if maxCmdLength > 16 then maxCmdLength else 16;

        formatGroup =
          { id, label }:
          let
            cmds = cmdsByGroup id;
          in
          if cmds == { } then
            ""
          else
            "  ${label}:\n"
            + concatStringsSep "\n" (
              mapAttrsToList (
                name: cmd:
                let
                  cmdDisplay = formatCmdName name cmd;
                  displayLen = builtins.stringLength cmdDisplay;
                  minSpacing = 2;
                in
                if displayLen + minSpacing >= paddingWidth then
                  "    ${cmdDisplay}\n${
                        concatStringsSep "" (builtins.genList (_: " ") (paddingWidth + 4))
                      }${cmd.description}"
                else
                  let
                    paddingLen = paddingWidth - displayLen;
                    padding = builtins.genList (_: " ") paddingLen;
                  in
                  "    ${cmdDisplay}${concatStringsSep "" padding}${cmd.description}"
              ) cmds
            )
            + "\n";

        groupsFormatted = concatStringsSep "\n" (filter (s: s != "") (map formatGroup groups));

        usageLines = concatStringsSep "\n" (
          mapAttrsToList (
            optName: opt:
            let
              a = opt.argument or null;
              argName = if a != null then " <${a.name}>" else "";
            in
            "       ${name} --${optName}${argName}"
          ) opts
        );

        formatOption =
          optName: opt:
          let
            a = opt.argument or null;
            argName = if a != null then " <${a.name}>" else "";
            fullDisplay =
              if opt ? short then "-${opt.short}, --${optName}${argName}" else "--${optName}${argName}";
            displayLen = builtins.stringLength fullDisplay;
            minSpacing = 2;
          in
          if displayLen + minSpacing >= paddingWidth then
            "    ${fullDisplay}\n${
                  concatStringsSep "" (builtins.genList (_: " ") (paddingWidth + 4))
                }${opt.description}"
          else
            let
              paddingLen = paddingWidth - displayLen;
              padding = builtins.genList (_: " ") paddingLen;
            in
            "    ${fullDisplay}${concatStringsSep "" padding}${opt.description}";

        optionsSection = concatStringsSep "\n" (mapAttrsToList formatOption opts);
      in
      ''
        Usage: ${name} <command> [args...]
        ${usageLines}

        Description:
          ${nxValidated.description}

        Commands:

        ${groupsFormatted}
        Options:
        ${optionsSection}
      '';
    meta = builtins.toJSON {
      inherit name version;
      commands = attrNames (getSubs nxValidated);
      options = map (n: "--${n}") (attrNames (getOpts nxValidated));
    };
  };

in
{
  inherit (outputs)
    bash
    zsh
    fish
    help
    meta
    ;
  inherit name version;
}
