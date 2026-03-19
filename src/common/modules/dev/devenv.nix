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
  name = "devenv";

  group = "dev";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        devenv
      ];

      programs.fish = {
        functions = {
          dev = ''
            if test (count $argv) -eq 0
              echo "Usage: dev <flake-name> [args...]"
              echo "Example: dev myproject"
              return 1
            end

            set flake_name $argv[1]
            set remaining_args $argv[2..]
            set develop_dir "$HOME/develop"
            set flakes_dir "$develop_dir/flakes"
            set target_dir "$flakes_dir/$flake_name"

            if not test -d "$develop_dir"
              echo "Error: Directory '$develop_dir' does not exist"
              echo "Please create the develop directory first"
              return 1
            end

            if not test -d "$flakes_dir"
              mkdir -p "$flakes_dir"
            end

            if not test -d "$target_dir"
              echo "Flake '$flake_name' does not exist at '$target_dir'"
              read -l -P "Create it with default template? [y/N] " create_flake
              
              if test "$create_flake" = "y" -o "$create_flake" = "Y"
                mkdir -p "$target_dir"
                
                echo 'Creating default flake.nix...'
                set -l flake_content '{
              inputs = {
                nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
                devenv.url = "github:cachix/devenv";
              };

              outputs = inputs@{ flake-parts, nixpkgs, ... }:
                flake-parts.lib.mkFlake { inherit inputs; } {
                  imports = [
                    inputs.devenv.flakeModule
                  ];
                  systems = nixpkgs.lib.systems.flakeExposed;

                  perSystem = { config, self\', inputs\', pkgs, system, ... }: {
                    packages.default = pkgs.hello;

                    # See: https://devenv.sh/guides/using-with-flake-parts/
                    devenv.shells.default = {
                      packages = [ config.packages.default ];

                      enterShell = \'\'
                        hello
                      \'\';
                    };
                  };
                };
            }'
                echo "$flake_content" > "$target_dir/flake.nix"
                echo "Created flake at '$target_dir'"
                echo "You can now edit '$target_dir/flake.nix' to customize your development environment"
                echo
                echo "Learn more at: https://devenv.sh/guides/using-with-flake-parts/"
                return 0
              else
                echo "Flake creation cancelled"
                return 1
              end
            end

            echo "Entering development shell for '$flake_name'..."
            if test (count $remaining_args) -gt 0
              nix develop --no-pure-eval "$target_dir" -c $remaining_args
            else
              nix develop --no-pure-eval "$target_dir"
            end
          '';
        };
      };
    };
}
