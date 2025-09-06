args@{
  lib,
  helpers,
  defs,
  user,
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
      user
      host
      ;
    configInputs = args.configInputs or { };
    isMainUser = args.isMainUser or false;
  };
  processedModules = funcs.collectAllModulesWithSettings buildArgs user.modules "home";
in
user
// {
  modules = processedModules;
  home =
    if (user.home or null) == null then
      if helpers.isLinuxArch host.architecture then
        "/home/${user.username}"
      else if helpers.isDarwinArch host.architecture then
        "/Users/${user.username}"
      else
        user.home
    else
      user.home;
}
