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
      graphics = [ "imagemagick" ];
      utils = [ "archive-tools" ];
      browser = [ "firefox" ];
      dev = [
        "conda"
        "just"
        "poetry"
        "uv"
        "devenv"
        "cmake"
        "utils"
        "direnv"
        "claude"
        "codex"
        "nodejs"
        "typescript-lsp"
        "jujutsu"
        "nixos-anywhere"
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
      nvim-modules = {
        minuet = true;
      };
    };
    groups.shell = [ "shell" ];
  };

  mergeModules =
    base: extra:
    lib.recursiveUpdate base extra
    // (lib.mapAttrs (
      name: value:
      if builtins.isAttrs value && builtins.isAttrs (base.${name} or null) then
        mergeModules base.${name} value
      else if builtins.isList value && builtins.isList (base.${name} or null) then
        base.${name} ++ value
      else
        value
    ) extra);

  baseLinuxModules = {
    common = {
      proton = [ "mail" ];
      photos = [ "ente" ];
      chat = [ "fluffychat" ];
      dev = [ "vscodium" ];
      git = [
        "git-credential-manager"
      ];
    };
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
      desktop-modules = [ "desktop-files" ];
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
      core = [ "coreutils" ];
      browser = [
        "qutebrowser"
      ];
      chat = [
        "beeper"
        "slack"
      ];
      dev = [
        "docker-desktop"
        "conda"
        "vscode"
      ];
      desktop = [
        "yabai"
        "better-display"
        "ovim"
      ];
      graphics = [ "gimp" ];
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
