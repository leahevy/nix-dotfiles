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

  submodules =
    let
      isLinux = self ? isLinux && self.isLinux;
      terminal = self.user.settings.terminal;
    in
    (
      if isLinux && terminal == "ghostty" then
        {
          linux = {
            terminal = {
              ghostty = {
                setEnv = true;
              };
            };
          };
        }
      else if !isLinux && terminal == "ghostty" then
        {
          common = {
            terminal = {
              ghostty-config = {
                setEnv = true;
              };
            };
          };
        }
      else if terminal == "kitty" then
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
      else
        throw "Unknown terminal setting: ${terminal}"
    );
}
