args@{
  lib,
  helpers,
  defs,
  host,
  funcs,
  pkgs,
  pkgs-unstable,
  inputs,
  variables,
  ...
}:

let
  buildArgs = {
    inherit
      lib
      pkgs
      pkgs-unstable
      inputs
      funcs
      helpers
      defs
      variables
      host
      ;
    users = { };
    configInputs = args.configInputs or { };
  };
  processedModules = funcs.collectAllModulesWithSettings buildArgs host.modules "system";
in
host
// {
  modules = processedModules;
}
