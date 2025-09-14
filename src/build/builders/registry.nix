{
  lib,
  inputs,
  ...
}:

let
  coreInputs = [
    "common"
    "linux"
    "darwin"
    "groups"
    "build"
    "config"
    "profile"
  ];

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
          scanModuleType =
            moduleType:
            let
              modulesPath = input + "/modules/${moduleType}";
            in
            if builtins.pathExists modulesPath then
              let
                groups = builtins.readDir modulesPath;

                scanGroup =
                  groupName: groupType:
                  let
                    groupPath = modulesPath + "/${groupName}";
                    modules =
                      if builtins.pathExists groupPath && groupType == "directory" then
                        builtins.readDir groupPath
                      else
                        { };
                  in
                  lib.mapAttrs (
                    moduleName: _:
                    let
                      modulePath = groupPath + "/${moduleName}/${moduleName}.nix";
                    in
                    if builtins.pathExists modulePath then
                      let
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

                        minimalContext = {
                          config = { };
                          options = { };
                        };

                        result = builtins.tryEval (
                          if builtins.isFunction moduleFunc then
                            let
                              moduleResult = moduleFunc minimalArgs;
                            in
                            {
                              name = moduleResult.name or moduleName;
                              description = moduleResult.description or "";
                            }
                          else
                            {
                              name = moduleFunc.name or moduleName;
                              description = moduleFunc.description or "";
                            }
                        );
                      in
                      let
                        baseMeta = {
                          name = moduleName;
                          description = lib.strings.concatStrings [
                            (lib.strings.toUpper (lib.strings.substring 0 1 moduleName))
                            (lib.strings.substring 1 (-1) moduleName)
                            " Configuration"
                          ];
                          group = groupName;
                          input = inputName;
                          moduleType = moduleType;
                          path = "modules/${moduleType}/${groupName}/${moduleName}/${moduleName}.nix";
                        };

                        moduleDir = groupPath + "/${moduleName}";

                        findSubmodules =
                          dir:
                          let
                            contents = if builtins.pathExists dir then builtins.readDir dir else { };
                            files = lib.filterAttrs (
                              name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "${moduleName}.nix"
                            ) contents;
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
                              fileName = baseNameOf filePath;
                              submoduleName = lib.removeSuffix ".nix" fileName;
                            in
                            {
                              name = filePath;
                              value = submoduleName;
                            }
                          ) (findSubmodules moduleDir)
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
                          finalDescription =
                            if moduleMeta.description or "" != "" then moduleMeta.description else baseMeta.description;
                        in
                        (baseMeta // moduleMeta // { description = finalDescription; }) // { inherit submodules; }
                      else
                        baseMeta // { inherit submodules; }
                    else
                      {
                        name = moduleName;
                        description = lib.strings.concatStrings [
                          (lib.strings.toUpper (lib.strings.substring 0 1 moduleName))
                          (lib.strings.substring 1 (-1) moduleName)
                          " Configuration"
                        ];
                        group = groupName;
                        input = inputName;
                        moduleType = moduleType;
                      }
                  ) modules;
              in
              builtins.mapAttrs scanGroup groups
            else
              { };
        in
        lib.filterAttrs (_: v: v != { }) {
          home = scanModuleType "home";
          system = scanModuleType "system";
        };
    in
    builtins.mapAttrs scanInput inputsWithModules;
in
{
  modules = buildModuleRegistry;
}
