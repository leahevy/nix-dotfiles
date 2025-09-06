args@{
  lib,
  helpers,
  defs,
  user,
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
      ;
    user = user;
    host = { };
    configInputs = args.configInputs or { };
    isMainUser = true;
  };
  processedModules = funcs.collectAllModulesWithSettings buildArgs user.modules "home";
in
user
// {
  modules = processedModules;
  home =
    if (user.home or null) == null then
      if helpers.isLinuxArch user.architecture then
        "/home/${user.username}"
      else if helpers.isDarwinArch user.architecture then
        "/Users/${user.username}"
      else
        user.home
    else
      user.home;
}
