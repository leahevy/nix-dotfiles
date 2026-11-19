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
  name = "jupyter";
  group = "services";
  input = "linux";

  description = "JupyterLab local server as a user systemd service";

  options = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 8888;
      description = "Port the JupyterLab server listens on.";
    };
    notebookDir = lib.mkOption {
      type = lib.types.str;
      default = "documents/jupyter";
      description = "Path relative to home directory for notebooks.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = ".local/share/jupyter/lab-token";
      description = "Path relative to home directory where the persistent auth token is stored.";
    };
    extraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      description = "Extra Python packages available in the JupyterLab environment.";
    };
  };

  module = {
    linux.enabled = config: {
      nx.packages.extra = [
        (pkgs.python3.withPackages (
          ps:
          [
            ps.jupyterlab
            ps.ipykernel
          ]
          ++ config.nx.linux.services.jupyter.extraPackages ps
        ))
      ];
    };

    linux.home =
      {
        config,
        port,
        notebookDir,
        tokenFile,
        extraPackages,
        ...
      }:
      let
        env = pkgs.python3.withPackages (
          ps:
          [
            ps.jupyterlab
            ps.ipykernel
          ]
          ++ extraPackages ps
        );
        tokenFilePath = "${config.home.homeDirectory}/${tokenFile}";
        prepareScript = pkgs.writeShellScript "jupyter-prepare" ''
          set -euo pipefail
          ${pkgs.coreutils}/bin/mkdir -p "${config.home.homeDirectory}/${notebookDir}"
          TOKEN_FILE="${tokenFilePath}"
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$TOKEN_FILE")"
          if [[ ! -f "$TOKEN_FILE" ]]; then
            ${pkgs.coreutils}/bin/touch "$TOKEN_FILE"
            ${pkgs.coreutils}/bin/chmod 600 "$TOKEN_FILE"
            ${pkgs.openssl}/bin/openssl rand -hex 32 > "$TOKEN_FILE"
          fi
        '';
      in
      {
        systemd.user.services.jupyter = {
          Unit.Description = "JupyterLab server";
          Service = {
            ExecStartPre = "${prepareScript}";
            ExecStart = "${env}/bin/jupyter lab --no-browser --ip=127.0.0.1 --port=${toString port} --notebook-dir=${config.home.homeDirectory}/${notebookDir}";
            Restart = "on-failure";
          };
        };

        systemd.user.timers.jupyter = {
          Unit = {
            Description = "JupyterLab startup timer";
            After = [ "graphical-session.target" ];
          };
          Timer = {
            OnActiveSec = "30s";
            Unit = "jupyter.service";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        home.file.".jupyter/jupyter_server_config.py" = {
          text = ''
            import os as _os
            _token_file = _os.path.expanduser("~/${tokenFile}")
            if _os.path.exists(_token_file):
                with open(_token_file, "r") as _f:
                    c.IdentityProvider.token = _f.read().strip()
          '';
        };

        home.persistence."${self.persist}" = {
          directories = [
            ".jupyter"
            ".local/share/jupyter"
            ".config/jupyter"
          ];
          files = [ ];
        };
      };
  };
}
