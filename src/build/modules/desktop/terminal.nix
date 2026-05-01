args@{
  lib,
  pkgs,
  pkgs-unstable,
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
      hasHost = self ? host && self.host != null && self.host ? settings;
      hasUser = self ? user && self.user != null && self.user ? settings;
      hasDesktop =
        if hasHost then
          self.host.settings.system.desktop != null
        else if hasUser && self.user ? settings && self.user.settings ? desktop then
          self.user.settings.desktop != null
        else
          false;
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
