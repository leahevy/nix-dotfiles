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
  name = "browser";

  group = "desktop";
  input = "build";

  submodules =
    let
      isLinux = self ? isLinux && self.isLinux;
      browser = self.user.settings.browser or null;
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
    if browser == "firefox" && hasDesktop then
      { common.browser.firefox = true; }
    else if browser == "qutebrowser" && isLinux && hasDesktop then
      { linux.browser.qutebrowser = true; }
    else if browser == "qutebrowser" && !isLinux && hasDesktop then
      { darwin.browser.qutebrowser = true; }
    else if browser == null || !hasDesktop then
      { }
    else
      throw "Unknown browser setting: ${browser}";

  module = {
    home =
      config:
      let
        browser = self.user.settings.browser or null;
      in
      {
        home.sessionVariables = lib.mkIf (browser != null) {
          BROWSER = browser;
        };
      };

    enabled =
      config:
      let
        browser = self.user.settings.browser or null;
      in
      lib.optionalAttrs (browser == "firefox") {
        nx.preferences.desktop.programs.webBrowser = {
          name = "firefox";
          package = null;
          localBin = true;
          openCommand = [ "firefox-wrapper" ];
          openFileCommand = path: [
            "firefox-wrapper"
            path
          ];
          desktopFile = "firefox.desktop";
        };
      }
      // lib.optionalAttrs (browser == "qutebrowser") {
        nx.preferences.desktop.programs.webBrowser = {
          name = "qutebrowser";
          package = null;
          openCommand = [ "qutebrowser" ];
          openFileCommand = path: [
            "qutebrowser"
            path
          ];
          desktopFile = "org.qutebrowser.qutebrowser.desktop";
        };
      };

    ifEnabled.linux.desktop.niri.enabled =
      config:
      let
        browser = self.user.settings.browser or null;
      in
      lib.optionalAttrs (browser == "firefox") {
        nx.linux.desktop.niri.autostartPrograms = [ "firefox" ];
      }
      // lib.optionalAttrs (browser == "qutebrowser") {
        nx.linux.desktop.niri.autostartPrograms = [ "qutebrowser" ];
      };
  };
}
