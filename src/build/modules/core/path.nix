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
  name = "path";
  group = "core";
  input = "build";

  module = {
    home = config: {
      home.sessionPath = [ self.binDir ];

      programs.bash.initExtra = lib.mkIf config.programs.bash.enable ''
        case ":$PATH:" in
          *:"${self.binForeignDir}":*) ;;
          *) export PATH="$PATH:${self.binForeignDir}" ;;
        esac
      '';

      programs.zsh.initContent = lib.mkIf config.programs.zsh.enable ''
        case ":$PATH:" in
          *:"${self.binForeignDir}":*) ;;
          *) export PATH="$PATH:${self.binForeignDir}" ;;
        esac
      '';

      programs.fish.interactiveShellInit = lib.mkIf config.programs.fish.enable ''
        fish_add_path --append --path "${self.binForeignDir}"
      '';

      home.activation.createBinForeignDir = (self.hmLib config).dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "${self.binForeignDir}" || true
      '';
    };
  };
}
