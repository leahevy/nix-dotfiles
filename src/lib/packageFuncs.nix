{
  defs,
  additionalInputs,
  helpers,
}:
pkgs:
let
  lib = pkgs.lib;
  haskellFuncs =
    let
      baseLanguageExtensions = [
        "OverloadedStrings"
        "LambdaCase"
        "ScopedTypeVariables"
        "BlockArguments"
      ];

      validModes = [
        "typed"
        "turtle"
        "shelly"
      ];

      validPresets = [
        "text"
        "bytestring"
        "directory"
        "filepath"
        "env"
        "temporary"
        "xdg"
        "containers"
        "time"
        "aeson"
        "optparse"
        "dbus"
        "journal"
        "regex"
      ];

      renderLanguageExtension = ext: "{-# LANGUAGE ${ext} #-}";

      renderLanguageExtensions = exts: lib.concatMapStringsSep "\n" renderLanguageExtension exts;

      renderGhcOption = opt: "{-# OPTIONS_GHC ${opt} #-}";

      renderGhcOptions = opts: lib.concatMapStringsSep "\n" renderGhcOption opts;

      renderImport = importSpec: "import ${importSpec}";

      renderImports = imports: lib.concatMapStringsSep "\n" renderImport imports;

      indent = text: lib.concatMapStringsSep "\n" (line: "  " + line) (lib.splitString "\n" text);

      mkMainDo = body: ''
        main :: IO ()
        main = do
        ${indent body}
      '';

      mkShellyMain = body: ''
        main :: IO ()
        main = shelly $ do
        ${indent body}
      '';

      temporaryPackage =
        hpkgs:
        if builtins.hasAttr "temporary" hpkgs then
          hpkgs.temporary
        else if builtins.hasAttr "temporary-rc" hpkgs then
          hpkgs."temporary-rc"
        else
          throw "writeHaskellShellScript: neither hpkgs.temporary nor hpkgs.temporary-rc exists!";

      typedPrelude = ''
        import System.Process.Typed
        import qualified Data.Text as T
        import qualified Data.ByteString as BS
        import qualified Data.ByteString.Lazy as BL
      '';

      turtlePrelude = ''
        import Turtle
      '';

      shellyPrelude = ''
        import Shelly
      '';

      modeConfigs = {
        typed = {
          prelude = typedPrelude;
          libraries = hpkgs: [
            hpkgs.typed-process
            hpkgs.text
            hpkgs.bytestring
          ];
          imports = [
            "System.Process.Typed"
            "qualified Data.Text as T"
            "qualified Data.ByteString as BS"
            "qualified Data.ByteString.Lazy as BL"
          ];
        };

        turtle = {
          prelude = turtlePrelude;
          helpers = ''
            procOutput :: Text -> [Text] -> IO Text
            procOutput cmd args = strict $ inproc cmd args Turtle.empty
          '';
          libraries = hpkgs: [
            hpkgs.turtle
          ];
          imports = [
            "Turtle"
          ];
        };

        shelly = {
          prelude = shellyPrelude;
          languageExtensions = [ "ExtendedDefaultRules" ];
          ghcOptions = [ "-fno-warn-type-defaults" ];
          libraries = hpkgs: [
            hpkgs.shelly
          ];
          imports = [
            "Shelly"
          ];
        };
      };

      presetConfigs = {
        text = {
          libraries = hpkgs: [
            hpkgs.text
          ];
          imports = [
            "Data.Text (Text)"
            "qualified Data.Text as T"
            "qualified Data.Text.IO as TIO"
            "qualified Data.Text.Encoding as TE"
          ];
        };

        bytestring = {
          libraries = hpkgs: [
            hpkgs.bytestring
          ];
          imports = [
            "qualified Data.ByteString as BS"
            "qualified Data.ByteString.Lazy as BL"
          ];
        };

        directory = {
          libraries = hpkgs: [
            hpkgs.directory
          ];
          imports = [
            "System.Directory"
          ];
        };

        filepath = {
          libraries = hpkgs: [
            hpkgs.filepath
          ];
          imports = [
            "System.FilePath"
          ];
        };

        env = {
          libraries = hpkgs: [ ];
          imports = [
            "System.Environment"
          ];
        };

        temporary = {
          libraries = hpkgs: [
            (temporaryPackage hpkgs)
          ];
          imports = [
            "System.IO.Temp"
          ];
        };

        xdg = {
          libraries = hpkgs: [
            hpkgs.xdg-basedir
          ];
          imports = [
            "System.Environment.XDG.BaseDir"
          ];
        };

        containers = {
          libraries = hpkgs: [
            hpkgs.containers
          ];
          imports = [
            "qualified Data.Map.Strict as Map"
            "qualified Data.Set as Set"
          ];
        };

        time = {
          libraries = hpkgs: [
            hpkgs.time
          ];
          imports = [
            "Data.Time"
          ];
        };

        aeson = {
          libraries = hpkgs: [
            hpkgs.aeson
          ];
          imports = [
            "qualified Data.Aeson as Aeson"
            "Data.Aeson ((.:))"
            "qualified Data.Aeson.Types as AesonTypes"
            "Control.Applicative ((<|>))"
            "qualified System.IO as SysIO"
            "System.Exit (exitFailure)"
          ];
          helpers = ''
            decodeOrDie :: (Aeson.Value -> AesonTypes.Parser a) -> Text -> Text -> IO a
            decodeOrDie parser msg json =
              maybe (SysIO.hPutStrLn SysIO.stderr (T.unpack msg) >> exitFailure) return $
                AesonTypes.parseMaybe parser =<< Aeson.decodeStrict (TE.encodeUtf8 json)
          '';
        };

        optparse = {
          libraries = hpkgs: [
            hpkgs.optparse-applicative
          ];
          imports = [
            "Options.Applicative"
          ];
        };

        dbus = {
          libraries = hpkgs: [
            hpkgs.dbus
          ];
          imports = [
            "DBus"
            "DBus.Client"
          ];
        };

        journal = {
          libraries = hpkgs: [
            hpkgs.libsystemd-journal
          ];
          imports = [
            "Systemd.Journal"
          ];
        };

        regex = {
          libraries = hpkgs: [
            hpkgs.regex-tdfa
          ];
          imports = [
            "Text.Regex.TDFA"
          ];
        };
      };

      getPresetConfig =
        preset:
        presetConfigs.${preset}
          or (throw "writeHaskellShellScript: invalid preset ${preset}; expected one of: ${lib.concatStringsSep ", " validPresets}!");

      unique = lib.unique;

      writeHaskellShellScript =
        {
          name,

          text ? null,
          source ? null,

          module ? "Main",
          mode ? "typed",

          inline ? false,

          imports ? [ ],
          presets ? [ ],

          inlinePresets ? lib.optionals (!strict) [
            "text"
            "bytestring"
            "directory"
            "filepath"
            "env"
            "temporary"
            "xdg"
            "regex"
          ],

          packages ? [ ],
          basePackages ? [
            pkgs.coreutils
            pkgs.curl
            pkgs.jq
            pkgs.git
            pkgs.rsync
            pkgs.unzip
            pkgs.gzip
            pkgs.gnutar
          ],
          libraries ? (_: [ ]),

          ghc ? pkgs.ghc,
          ghcArgs ? [ ],
          languageExtensions ? [ ],

          debug ? false,
          strict ? false,

          optimize ? (!debug),
          optimizeFlag ? "-O2",

          extraCode ? "",
          makeWrapperArgs ? [ ],
        }:
        let
          modeConfig =
            modeConfigs.${mode}
              or (throw "writeHaskellShellScript: invalid mode `${mode}`; expected one of: ${lib.concatStringsSep ", " validModes}!");

          rawSourceText =
            if text != null && source != null then
              throw "writeHaskellShellScript `${name}`: only one of `text` or `source` may be set!"
            else if text != null then
              text
            else if source != null then
              builtins.readFile source
            else
              throw "writeHaskellShellScript `${name}`: one of `text` or `source` must be set!";

          sourceText =
            if !inline then
              rawSourceText
            else if mode == "shelly" then
              mkShellyMain rawSourceText
            else
              mkMainDo rawSourceText;

          effectivePresets = presets ++ lib.optionals inline inlinePresets;

          presetConfigList = map getPresetConfig effectivePresets;

          presetImports = unique (lib.concatMap (preset: preset.imports) presetConfigList);

          modeImports = modeConfig.imports;

          renderedExtraImports = renderImports (
            unique (lib.subtractLists modeImports (presetImports ++ imports))
          );

          optimizationFlag = if optimize then optimizeFlag else "-O0";

          finalGhcArgs = [
            optimizationFlag
            "-main-is"
            "${module}.main"
          ]
          ++ lib.optionals debug [
            "-g"
            "-fno-ignore-asserts"
          ]
          ++ lib.optionals strict [
            "-Wall"
            "-Werror"
          ]
          ++ ghcArgs;

          modeHelpers = modeConfig.helpers or "";

          presetHelpers = lib.concatStringsSep "\n\n" (
            lib.filter (s: s != "") (map (p: p.helpers or "") presetConfigList)
          );

          fullSource = ''
            ${renderLanguageExtensions (
              baseLanguageExtensions ++ (modeConfig.languageExtensions or [ ]) ++ languageExtensions
            )}
            ${renderGhcOptions (modeConfig.ghcOptions or [ ])}

            module ${module} where

            ${modeConfig.prelude}

            ${renderedExtraImports}

            ${modeHelpers}

            ${presetHelpers}

            ${extraCode}

            ${sourceText}
          '';

          normalizedSource =
            let
              normalize =
                s:
                let
                  next = builtins.replaceStrings [ "\n\n\n" ] [ "\n\n" ] s;
                in
                if next == s then s else normalize next;
              stripTrailing =
                s:
                let
                  next = lib.removeSuffix "\n\n" s;
                in
                if next == s then s else stripTrailing next;
            in
            (stripTrailing (normalize fullSource));

          hpkgs = pkgs.haskellPackages;

          resolvedLibraries =
            modeConfig.libraries hpkgs
            ++ unique (lib.concatMap (preset: preset.libraries hpkgs) presetConfigList)
            ++ libraries hpkgs;

        in
        pkgs.writers.writeHaskellBin name {
          inherit ghc;

          libraries = resolvedLibraries;

          ghcArgs = finalGhcArgs;

          strip = !debug && optimize;
          threadedRuntime = true;

          makeWrapperArgs =
            makeWrapperArgs
            ++ lib.optionals ((basePackages ++ packages) != [ ]) [
              "--prefix"
              "PATH"
              ":"
              (lib.makeBinPath (unique (basePackages ++ packages)))
            ];
        } normalizedSource;
    in
    rec {
      inherit writeHaskellShellScript;

      writeTypedProcessScript = args: writeHaskellShellScript (args // { mode = "typed"; });
      writeTurtleScript = args: writeHaskellShellScript (args // { mode = "turtle"; });
      writeShellyScript = args: writeHaskellShellScript (args // { mode = "shelly"; });

      writeTypedProcessScriptSimple = name: text: writeTypedProcessScript { inherit name text; };
      writeTurtleScriptSimple = name: text: writeTurtleScript { inherit name text; };
      writeShellyScriptSimple = name: text: writeShellyScript { inherit name text; };

      writeTypedProcessScriptInline =
        name: text:
        writeTypedProcessScript {
          inherit name text;
          inline = true;
        };
      writeTurtleScriptInline =
        name: text:
        writeTurtleScript {
          inherit name text;
          inline = true;
        };
      writeShellyScriptInline =
        name: text:
        writeShellyScript {
          inherit name text;
          inline = true;
        };
    };
in
haskellFuncs
