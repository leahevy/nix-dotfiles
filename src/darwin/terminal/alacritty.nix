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
  name = "alacritty";

  group = "terminal";
  input = "darwin";

  submodules = {
    common = {
      terminal = {
        alacritty-config = {
          setEnv = false;
        };
      };
    };
  };

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "alacritty" ];

      nx.preferences.desktop.programs.additionalTerminal = {
        name = lib.mkForce "Alacritty";
        commandIsAbsolute = lib.mkForce true;
        execFlag = lib.mkForce [ "-e" ];
        classFlag = lib.mkForce (class: [ ]);
        directoryFlag = lib.mkForce (path: [
          "--args"
          "--working-directory=${path}"
        ]);
        openCommand = lib.mkForce [
          "open"
          "-nWa"
          "Alacritty"
        ];
        openDirectoryCommand = lib.mkForce (path: [
          "open"
          "-nWa"
          "Alacritty"
          "--args"
          "--working-directory=${path}"
        ]);
        openRunCommand = lib.mkForce (cmd: [
          "open"
          "-nWa"
          "Alacritty"
          "--args"
          "-e"
          cmd
        ]);
        openRunPrefix = lib.mkForce [
          "open"
          "-nWa"
          "Alacritty"
          "--args"
          "-e"
        ];
        openShellCommand = lib.mkForce (cmd: [
          "open"
          "-nWa"
          "Alacritty"
          "--args"
          "-e"
          "sh"
          "-c"
          cmd
        ]);
        openWithClass = lib.mkForce (class: [
          "open"
          "-nWa"
          "Alacritty"
        ]);
        openRunWithClass = lib.mkForce (
          class: cmd: [
            "open"
            "-nWa"
            "Alacritty"
            "--args"
            "-e"
            cmd
          ]
        );
        openShellCommandWithClass = lib.mkForce (
          class: cmd: [
            "open"
            "-nWa"
            "Alacritty"
            "--args"
            "-e"
            "sh"
            "-c"
            cmd
          ]
        );
      };
    };
  };
}
