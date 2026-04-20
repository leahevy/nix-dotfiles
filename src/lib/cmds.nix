{
  lib,
  rootPath,
  scope,
  system,
  architectures,
  mode ? "develop",
  hasImpermanence ? false,
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
    helpOption = {
      help = {
        description = "Show help message";
        short = "h";
      };
    };

    commonDeploymentOptions = {
      offline = option "Run without network access";
      show-trace = option "Show detailed Nix error traces";
      allow-dirty-git = option "Allow proceeding with uncommitted changes";
      skip-verification = option "Skip commit signature verification";
      allow-ifd = option "Allow import-from-derivation";
    };

    gitOptions = {
      only-core = option "Run only on core repository";
      only-config = option "Run only on config repository";
    };
  };

  inherit (sharedOptions) helpOption commonDeploymentOptions gitOptions;

  deploymentSpec = import (rootPath + "/scripts/utils/deployment.nix") {
    inherit
      architectures
      option
      optionWith
      optionWithDefault
      optionWithEnum
      optionRepeatable
      arg
      argVariadic
      commonDeploymentOptions
      gitOptions
      ;
  };

  inherit (deploymentSpec)
    name
    version
    groups
    nx
    ;

  defs = import ./defs.nix { inherit lib; };
  gitRepoPath = "~/${defs.nxConfigPath}/${defs.coreDirName}";

  reservedOptions = [ "help" ];

  assertNoReservedOptions =
    path: cmd:
    let
      cmdOptions = attrNames (cmd.options or { });
      conflicts = filter (opt: elem opt reservedOptions) cmdOptions;
      subResults = mapAttrsToList (name: sub: assertNoReservedOptions "${path}.subcommands.${name}" sub) (
        cmd.subcommands or { }
      );
    in
    if conflicts != [ ] then
      throw "${path}: commands must not define reserved options [${concatStringsSep ", " conflicts}] (they are injected automatically)"
    else
      all (x: x) subResults;

  injectHelpOptions =
    cmd:
    cmd
    // {
      options = (cmd.options or { }) // helpOption;
      subcommands = builtins.mapAttrs (_: injectHelpOptions) (cmd.subcommands or { });
    };

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

    validModes = [
      "managed"
      "server"
      "local"
      "develop"
    ];

    validImpermanence = [
      "always"
      "enabled"
      "disabled"
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
      "modes"
      "impermanence"
    ];

    allowedOptionFields = [
      "description"
      "short"
      "argument"
      "repeatable"
      "scope"
      "system"
      "modes"
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
      "modes"
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

    assertValidModes =
      path: obj:
      if obj ? modes then
        if !(isList obj.modes) then
          throw "${path}.modes: must be a list"
        else
          let
            invalid = filter (m: !(elem m validModes)) obj.modes;
          in
          if invalid != [ ] then
            throw "${path}.modes: invalid values [${concatStringsSep ", " invalid}], allowed: [${concatStringsSep ", " validModes}]"
          else
            true
      else
        true;

    assertValidOption =
      path: opt:
      assertKnownFields allowedOptionFields opt path
      && assertRequiredFields [ "description" ] opt path
      && assertFieldEnum "scope" validScopes opt path
      && assertFieldEnum "system" validSystems opt path
      && assertValidModes path opt
      && (if opt ? argument then assertValidOptionValue "${path}.argument" opt.argument else true);

    assertValidArgument =
      path: a:
      assertKnownFields allowedArgumentFields a path
      && assertRequiredFields [ "name" "description" "type" ] a path
      && assertFieldEnum "type" validTypes a path
      && assertFieldEnum "scope" validScopes a path
      && assertFieldEnum "system" validSystems a path
      && assertValidModes path a
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
      && assertFieldEnum "impermanence" validImpermanence cmd path
      && assertValidModes path cmd
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
      && assertFieldEnum "impermanence" validImpermanence cmd path
      && assertValidModes path cmd
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
          m = cmd.modes or [ ];
          i = cmd.impermanence or "always";
        in
        (s == "both" || s == scope)
        && (p == "both" || p == system)
        && (m == [ ] || elem mode m)
        && (i == "always" || (i == "enabled" && hasImpermanence) || (i == "disabled" && !hasImpermanence))
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
            m = a.modes or [ ];
          in
          (s == "both" || s == scope) && (p == "both" || p == system) && (m == [ ] || elem mode m)
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
    assert assertNoReservedOptions "nx" nx;
    assert assertValidCommand "nx" nx;
    assert assertValidGroups "nx" nx (map (g: g.id) groups);
    assert assertUniqueShortFlags "nx" nx;
    injectHelpOptions (filterTree nx);

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
              "complete -c ${name} -n \"not __fish_seen_subcommand_from ${allSubsStr}\" -l ${optName}${shortFlag} -d \"${opt.description}\"";
          in
          "\n" + concatStringsSep "\n" (mapAttrsToList formatGlobalOpt opts);

      in
      ''
        ${topLevel}
        ${perCmdSections}
        ${branchHelper}
        ${globalOpts}
      '';

    json = builtins.toJSON (
      nxValidated
      // {
        inherit name version;
        inherit groups;
      }
    );
  };

in
{
  inherit (outputs)
    bash
    zsh
    fish
    json
    ;
  inherit name version;
}
