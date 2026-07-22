args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "terminal";
  group = "desktop";
  input = "build";

  submodules =
    let
      isLinux = self ? isLinux && self.isLinux;
      terminal = self.user.settings.terminal;
      hasDesktop = helpers.hasDesktop self;
    in
    (
      if isLinux && hasDesktop && terminal == "ghostty" then
        {
          linux = {
            terminal = {
              ghostty = {
                setEnv = true;
              };
            };
          };
        }
      else if !isLinux && hasDesktop && terminal == "ghostty" then
        {
          darwin = {
            terminal = {
              ghostty = true;
            };
          };
        }
      else if hasDesktop && terminal == "kitty" then
        {
          common = {
            terminal = {
              kitty = {
                setEnv = true;
              };
            };
          };
        }
      else if terminal == null then
        { }
      else if hasDesktop then
        throw "Unknown terminal setting: ${terminal}"
      else
        { }
    );
}
