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
    basePackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = ps: [
        ps.pandas
        ps.numpy
        ps.scipy
        ps.matplotlib
        ps.seaborn
        ps.scikit-learn
        ps.ipywidgets
        ps.requests
        ps.tqdm
        ps.pillow
        ps.nbconvert
        ps.pytest
      ];
      description = "Base Python packages made available in the JupyterLab environment.";
    };
    enablePlotly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include plotly and kaleido in the base Python packages.";
    };
    enableTexlive = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include texliveFull in the service PATH.";
    };
    extraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      description = "Extra Python packages available in the JupyterLab environment.";
    };
    extraWebAppPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      description = "Extra Python packages available in the JupyterLab environment (declared by web-app).";
    };
    baseTools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [
        pkgs.coreutils
        pkgs.pandoc
        pkgs.ghostscript
        pkgs.inkscape
      ];
      description = "Base non-Python tools added to the service PATH.";
    };
    extraTools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra non-Python tools added to the service PATH.";
    };
    extraWebAppTools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra non-Python tools added to the service PATH (declared by web-app).";
    };
  };

  module = {
    overlays = [
      (final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (_pFinal: pPrev: {
            databricks-sql-connector = pPrev.databricks-sql-connector.overridePythonAttrs (_: {
              doCheck = false;
            });
          })
        ];
      })
    ];

    linux.enabled = config: {
      nx.packages.extra = [
        (pkgs.python3.withPackages (
          ps:
          [
            ps.jupyterlab
            ps.ipykernel
          ]
          ++ config.nx.linux.services.jupyter.basePackages ps
          ++ lib.optionals config.nx.linux.services.jupyter.enablePlotly [
            ps.plotly
            ps.kaleido
          ]
          ++ config.nx.linux.services.jupyter.extraPackages ps
          ++ config.nx.linux.services.jupyter.extraWebAppPackages ps
        ))
      ]
      ++ config.nx.linux.services.jupyter.baseTools
      ++ lib.optionals config.nx.linux.services.jupyter.enableTexlive [ pkgs.texliveFull ]
      ++ config.nx.linux.services.jupyter.extraTools
      ++ config.nx.linux.services.jupyter.extraWebAppTools;
    };

    linux.home =
      {
        config,
        port,
        notebookDir,
        tokenFile,
        basePackages,
        enablePlotly,
        extraPackages,
        extraWebAppPackages,
        baseTools,
        enableTexlive,
        extraTools,
        extraWebAppTools,
        ...
      }:
      let
        env = pkgs.python3.withPackages (
          ps:
          [
            ps.jupyterlab
            ps.ipykernel
          ]
          ++ basePackages ps
          ++ lib.optionals enablePlotly [
            ps.plotly
            ps.kaleido
          ]
          ++ extraPackages ps
          ++ extraWebAppPackages ps
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
            Environment = [
              "PATH=${
                lib.makeBinPath (
                  baseTools ++ lib.optionals enableTexlive [ pkgs.texliveFull ] ++ extraTools ++ extraWebAppTools
                )
              }"
            ];
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
