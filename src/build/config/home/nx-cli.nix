{
  lib,
  pkgs,
  defs,
  inputs,
  scope,
  deploymentMode,
}:
rec {
  mkNxDef =
    extraCommands:
    import (inputs.lib + "/cmds.nix") {
      inherit lib extraCommands scope;
      architectures = import inputs.nix-systems;
      rootPath = defs.rootPath;
      system = if pkgs.stdenv.isDarwin then "darwin" else "linux";
      mode = deploymentMode;
    };

  nxCliEnabled = deploymentMode != "managed";

  package =
    nxDef:
    pkgs.stdenv.mkDerivation {
      name = "nx";
      src = builtins.path {
        path = defs.rootPath;
        name = "nx-source";
        filter =
          path: type:
          let
            baseName = builtins.baseNameOf path;
          in
          baseName == "nx"
          || baseName == "scripts"
          || lib.hasPrefix (toString defs.rootPath + "/scripts/") (toString path);
      };
      dontAuditTmpdir = true;
      installPhase = ''
                        mkdir -p $out/bin $out/share/nx/scripts/utils
                        cp -r scripts $out/share/nx/
                        cp nx $out/share/nx/
                        chmod +x $out/share/nx/scripts/utils/nx-help-formatter.py

                        find $out/share/nx/scripts -type f -exec sh -c '
                          if head -1 "$1" 2>/dev/null | grep -q "^#!/usr/bin/env bash"; then
                            chmod +w "$1"
                            sed -i "1s|#!/usr/bin/env bash|#!${pkgs.bash}/bin/bash|" "$1"
                            chmod -w "$1"
                          fi
                        ' _ {} \;

                        if head -1 $out/share/nx/nx 2>/dev/null | grep -q "^#!/usr/bin/env bash"; then
                          chmod +w $out/share/nx/nx
                          sed -i "1s|#!/usr/bin/env bash|#!${pkgs.bash}/bin/bash|" $out/share/nx/nx
                          chmod -w $out/share/nx/nx
                        fi

                        cat > $out/bin/nx << EOF
        #!${pkgs.bash}/bin/bash
        export ACTUAL_PWD="\$PWD"
        export NX_INSTALL_PATH="$out/share/nx"
        cd $out/share/nx
        exec $out/share/nx/nx "\$@"
        EOF
                        chmod +x $out/bin/nx

                        cp ${pkgs.writeText "nx-spec.json" nxDef.json} $out/share/nx/nx-spec.json
      '';
    };

  packages = nxDef: [
    (package nxDef)
    pkgs.jq
    pkgs.yq
  ];

  mkCompletionFiles =
    nxDef: config:
    lib.optionalAttrs (config.programs.fish.enable or false) {
      ".config/fish/completions/nx.fish".text = nxDef.fish;
    }
    // lib.optionalAttrs (config.programs.bash.enable or false) {
      ".local/share/bash-completion/completions/nx".text = nxDef.bash;
    }
    // lib.optionalAttrs (config.programs.zsh.enable or false) {
      ".local/share/zsh/site-functions/_nx".text = nxDef.zsh;
    };

  sessionVariables = {
    NXCORE_DIR = "$HOME/.config/nx/nxcore";
    NXCONFIG_DIR = "$HOME/.config/nx/nxconfig";
  };
}
