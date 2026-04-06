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
  baseModules = {
    common = {
      proton = [ "mail" ];
      photos = [ "ente" ];
      utils = [ "archive-tools" ];
      browser = [ "firefox" ];
      dev = [
        "conda"
        "poetry"
        "uv"
        "devenv"
        "cmake"
        "utils"
        "direnv"
        "claude"
        "nodejs"
        "typescript-lsp"
        "vscodium"
      ];
      services = [
        "ollama"
        "ssh-agent"
      ];
      fonts = [
        "japanese"
        "general"
        "fontconfig"
        "nerdfonts"
      ];
      git = [
        "git"
        "lazygit"
        "git-credential-manager"
      ];
      gpg = [ "gpg" ];
      nix = [
        "nix-index"
        "nix-search-tv"
        "comma"
      ];
      passwords = [
        "keepassxc"
        "bitwarden"
      ];
      python = [ "python" ];
      shell = [
        "fastfetch"
        "starship"
        "file-manager"
        "go-programs"
        "timg"
        "yazi"
        "clipboard"
      ];
      spell = [ "ispell" ];
      tmux = [ "tmux" ];
      nvim = [ "nixvim" ];
      chat = [ "fluffychat" ];
    };
    groups.shell = [ "shell" ];
  };

  mergeModules = base: extra: lib.recursiveUpdate base extra;

  baseLinuxModules = {
    linux = {
      chat = [
        "beeper"
        "signal"
      ];
      browser = [ "qutebrowser" ];
      utils = [ "alien" ];
      gnome = [
        "keyring"
        "gtk"
      ];
      organising = [ "logseq" ];
      todo = [ "todoist" ];
      xdg = [ "user-dirs" ];
      music = [ "spotify" ];
    };
  };

  nixosIntegratedModules = mergeModules baseModules (
    mergeModules baseLinuxModules {
      linux.notifications = [ "user-notify" ];
    }
  );

  linuxStandaloneModules = mergeModules baseModules (
    mergeModules baseLinuxModules {
      common.style = [ "stylix" ];
    }
  );

  macosStandaloneModules = mergeModules baseModules {
    common.style = [ "stylix" ];
    darwin = {
      software = [ "homebrew" ];
      browser = [
        "firefox"
        "qutebrowser"
      ];
      chat = [
        "beeper"
        "slack"
      ];
      dev = [
        "docker-desktop"
        "conda"
      ];
      desktop = [
        "yabai"
        "better-display"
        "ovim"
      ];
      music = [ "spotify" ];
      organising = [ "logseq" ];
      passwords = [ "keepassxc" ];
      terminal = [
        "alacritty"
        "ghostty"
      ];
    };
    groups.darwin = [ "settings" ];
  };
in
{
  name = "home-manager";
  description = "Home Manager base group";

  group = "base";
  input = "groups";

  submodules =
    if
      (self ? isLinux && self.isLinux)
      && (self ? user && self.user ? isStandalone && !self.user.isStandalone)
    then
      nixosIntegratedModules
    else if
      (self ? isLinux && self.isLinux)
      && (self ? user && self.user ? isStandalone && self.user.isStandalone)
    then
      linuxStandaloneModules
    else if
      (self ? isDarwin && self.isDarwin)
      && (self ? user && self.user ? isStandalone && self.user.isStandalone)
    then
      macosStandaloneModules
    else
      { };
}
