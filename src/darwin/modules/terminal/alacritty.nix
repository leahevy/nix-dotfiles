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

  on = {
    darwin.init =
      config:
      lib.mkIf self.isEnabled {
        nx.preferences.desktop.programs.additionalTerminal = {
          name = lib.mkForce "Alacritty";
          commandIsAbsolute = lib.mkForce true;
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
        };
      };

    darwin.enabled = config: {
      nx.homebrew.casks = [ "alacritty" ];
    };
  };
}
