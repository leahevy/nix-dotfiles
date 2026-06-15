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
let
  ha-assets = pkgs.fetchFromGitHub {
    owner = "home-assistant";
    repo = "assets";
    rev = "690cb80f94a305b51297f5584aa6d640dd96ec4b";
    hash = "sha256-T2aHj1XF39MNAAcztzU0q6DA1AXswzHoLO5CO6o9Ymo=";
  };

  ha-icon =
    pkgs.runCommand "home-assistant-icon.png"
      {
        nativeBuildInputs = [ pkgs.unzip ];
      }
      ''
        unzip ${ha-assets}/logo/home-assistant-logo.zip \
          home-assistant-social-media-logo-square.png
        cp home-assistant-social-media-logo-square.png $out
      '';
in
{
  name = "home-assistant";

  group = "web-apps";
  input = "linux";

  settings = {
    name = "Home-Assistant";
    webapp = "home-assistant";
    iconPath = "${ha-icon}";
    categories = [
      "Network"
      "System"
      "Utility"
    ];
    protocol = "https";
    subdomain = "";
    args = "";
    domain =
      if self ? user && self.user.isStandalone then
        self.user.homeserverDomain
      else if self ? host then
        self.host.homeserverDomain
      else
        null;
  };

  submodules = {
    linux = {
      desktop-modules = {
        web-app = true;
      };
    };
  };

  assertions = [
    {
      assertion = self.settings.subdomain != null && self.settings.subdomain != "";
      message = "Subdomain required to be set!";
    }
    {
      assertion = self.settings.domain != null && self.settings.domain != "";
      message = "Domain required to be set!";
    }
  ];

  module = {
    linux.home = config: {
      home.file = (config.nx.linux.desktop-modules.web-app.buildWebApp self.settings).homeFiles;
      xdg.desktopEntries =
        (config.nx.linux.desktop-modules.web-app.buildWebApp self.settings).desktopEntries;
    };
  };
}
