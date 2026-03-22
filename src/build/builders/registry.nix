{
  lib,
  inputs,
  defs,
  ...
}:

let
  coreInputs = defs.moduleInputsToScan;

  configInputs = inputs.config.configInputs or { };

  allowedInputs = coreInputs ++ (builtins.attrNames configInputs);

  buildModuleRegistry =
    let
      allInputs = inputs // configInputs;

      inputsWithModules = lib.filterAttrs (
        name: input:
        name != "self" && builtins.elem name allowedInputs && builtins.pathExists (input + "/modules")
      ) allInputs;

      scanInput =
        inputName: input:
        let
          modulesPath = input + "/modules";
        in
        if builtins.pathExists modulesPath then
          let
            groups = builtins.readDir modulesPath;

            scanGroup =
              groupName: groupType:
              let
                groupPath = modulesPath + "/${groupName}";
                entries =
                  if builtins.pathExists groupPath && groupType == "directory" then
                    builtins.readDir groupPath
                  else
                    { };
              in
              lib.filterAttrs (_: v: v != null) (
                lib.mapAttrs' (
                  fileName: entryType:
                  let
                    moduleName = lib.removeSuffix ".nix" fileName;
                  in
                  if entryType == "regular" && lib.hasSuffix ".nix" fileName then
                    let
                      modulePath = groupPath + "/${fileName}";
                      moduleFunc = import modulePath;

                      minimalArgs = {
                        lib = lib;
                        pkgs = { };
                        pkgs-unstable = { };
                        funcs = { };
                        helpers = { };
                        defs = { };
                        self = { };
                      };

                      result = builtins.tryEval (
                        if builtins.isFunction moduleFunc then
                          let
                            moduleResult = moduleFunc minimalArgs;
                          in
                          {
                            name = moduleResult.name or moduleName;
                            description = moduleResult.description or "";
                            options = moduleResult.options or { };
                            rawOptions = moduleResult.rawOptions or { };
                            hasInit = (moduleResult.on or { }) ? init;
                          }
                        else
                          {
                            name = moduleFunc.name or moduleName;
                            description = moduleFunc.description or "";
                            options = moduleFunc.options or { };
                            rawOptions = moduleFunc.rawOptions or { };
                            hasInit = (moduleFunc.on or { }) ? init;
                          }
                      );

                      baseMeta = {
                        name = moduleName;
                        description = lib.strings.concatStrings [
                          (lib.strings.toUpper (lib.strings.substring 0 1 moduleName))
                          (lib.strings.substring 1 (-1) moduleName)
                          " Configuration"
                        ];
                        group = groupName;
                        input = inputName;
                        path = "modules/${groupName}/${moduleName}.nix";
                      };

                      nixDDir = groupPath + "/${moduleName}.nix.d";

                      findSubmodules =
                        dir:
                        let
                          contents = if builtins.pathExists dir then builtins.readDir dir else { };
                          files = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) contents;
                          subdirs = lib.filterAttrs (name: type: type == "directory") contents;
                          subFiles = lib.concatMap (
                            subdir: map (file: "${subdir}/${file}") (findSubmodules (dir + "/" + subdir))
                          ) (builtins.attrNames subdirs);
                        in
                        (builtins.attrNames files) ++ subFiles;

                      submoduleFiles = lib.listToAttrs (
                        map (
                          filePath:
                          let
                            submoduleName = lib.removeSuffix ".nix" (baseNameOf filePath);
                          in
                          {
                            name = filePath;
                            value = submoduleName;
                          }
                        ) (findSubmodules nixDDir)
                      );

                      extractSubmoduleMeta = filePath: submoduleName: {
                        name = submoduleName;
                        description = "";
                        path = filePath;
                      };

                      submodules = builtins.attrValues (builtins.mapAttrs extractSubmoduleMeta submoduleFiles);
                    in
                    if result.success then
                      let
                        moduleMeta = result.value;
                        excludedAttrs = [
                          "options"
                          "rawOptions"
                          "on"
                          "assertions"
                          "custom"
                        ];
                        filteredMeta = lib.filterAttrs (
                          n: v: !builtins.isFunction v && !builtins.elem n excludedAttrs
                        ) moduleMeta;
                        finalDescription =
                          if moduleMeta.description or "" != "" then moduleMeta.description else baseMeta.description;
                        hasOptions = (moduleMeta.options or { }) != { };
                        hasRawOptions = (moduleMeta.rawOptions or { }) != { };
                      in
                      lib.nameValuePair moduleName (
                        (
                          baseMeta
                          // filteredMeta
                          // {
                            description = finalDescription;
                            inherit hasOptions hasRawOptions;
                          }
                        )
                        // {
                          inherit submodules;
                        }
                      )
                    else
                      lib.nameValuePair moduleName (baseMeta // { inherit submodules; })
                  else
                    lib.nameValuePair moduleName null
                ) entries
              );
          in
          lib.filterAttrs (_: v: v != { }) (builtins.mapAttrs scanGroup groups)
        else
          { };
    in
    builtins.mapAttrs scanInput inputsWithModules;
in
{
  modules = buildModuleRegistry;
}
