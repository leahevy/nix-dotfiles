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
  name = "ghostty";

  group = "terminal";
  input = "darwin";
  namespace = "home";

  submodules = {
    darwin = {
      software = {
        homebrew = true;
      };
    };
    common = {
      terminal = {
        ghostty-config = {
          setEnv = true;
        };
      };
    };
  };

  init =
    context@{ config, options, ... }:
    lib.mkIf self.isEnabled {
      nx.preferences.desktop.programs.terminal = {
        name = lib.mkForce "Ghostty";
        commandIsAbsolute = lib.mkForce true;
        openCommand = lib.mkForce [
          "open"
          "-nWa"
          "Ghostty"
        ];
        openDirectoryCommand = lib.mkForce (path: [
          "open"
          "-nWa"
          "Ghostty"
          "--args"
          "--working-directory=${path}"
        ]);
        openRunCommand = lib.mkForce (cmd: [
          "open"
          "-nWa"
          "Ghostty"
          "--args"
          "-e"
          cmd
        ]);
        openRunPrefix = lib.mkForce [
          "open"
          "-nWa"
          "Ghostty"
          "--args"
          "-e"
        ];
        openShellCommand = lib.mkForce (cmd: [
          "open"
          "-nWa"
          "Ghostty"
          "--args"
          "-e"
          "sh"
          "-c"
          cmd
        ]);
        openWithClass = lib.mkForce (class: [
          "open"
          "-nWa"
          "Ghostty"
        ]);
        openRunWithClass = lib.mkForce (
          class: cmd: [
            "open"
            "-nWa"
            "Ghostty"
            "--args"
            "-e"
            cmd
          ]
        );
      };
      nx.preferences.desktop.programs.additionalTerminal =
        lib.mkDefault config.nx.preferences.desktop.programs.terminal;
    };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/ghostty.brew".text = ''
        cask 'ghostty'
      '';
    };

}
