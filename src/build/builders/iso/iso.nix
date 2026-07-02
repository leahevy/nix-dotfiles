{
  lib,
  inputs,
  config,
  build,
  variables,
  helpers,
  defs,
  funcs,
  nixosArchitectures,
}:
let
  mkNxRepositories =
    pkgs:
    pkgs.stdenv.mkDerivation {
      name = "nx-repositories";
      src = inputs.self;
      configSrc = inputs.config;
      buildPhase = "true";
      installPhase = ''
        mkdir -p $out/nxcore $out/nxconfig
        cp -r $src/. $out/nxcore/
        cp -r $configSrc/. $out/nxconfig/
        chmod -R u+w $out/nxcore $out/nxconfig

        rm -f $out/nxconfig/nxcore $out/nxconfig/templates

        if [ -f "$configSrc/.git-crypt-key" ]; then
          mkdir -p $out/keys
          cp "$configSrc/.git-crypt-key" $out/keys/git-crypt-key
          echo "git-crypt key included in package"
        elif [ -d "$configSrc/.git/git-crypt" ]; then
          echo "Warning: Config repository uses git-crypt but key was not exported"
          echo "Make sure to run makeiso.sh with an unlocked repository"
        else
          echo "Config repository is not encrypted (no git-crypt detected)"
        fi
      '';
    };

  mkIsoSpecialArgs = pkgs: {
    inherit inputs variables helpers;
    nx-repositories = mkNxRepositories pkgs;
  };

  buildIsoConfiguration =
    { arch }:
    let
      system = arch;
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: true;
      };
    in
    {
      name = arch;
      value = inputs.nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = mkIsoSpecialArgs pkgs;
        modules = [
          (inputs.build + "/config/iso/live-iso.nix")
          inputs.disko.nixosModules.disko
        ];
      };
    };

  buildPiInstallerConfiguration =
    let
      system = "aarch64-linux";
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: true;
      };
    in
    {
      name = "pi5";
      value = inputs.nixos-raspberrypi.lib.nixosInstaller {
        trustCaches = false;
        specialArgs = mkIsoSpecialArgs pkgs;
        modules = with inputs.nixos-raspberrypi.nixosModules; [
          raspberry-pi-5.base
          (inputs.build + "/config/iso/live-pi.nix")
          inputs.disko.nixosModules.disko
        ];
      };
    };
in
{
  buildIsoConfigurations =
    builtins.listToAttrs (
      lib.flatten (map (arch: buildIsoConfiguration { inherit arch; }) nixosArchitectures)
    )
    // builtins.listToAttrs [ buildPiInstallerConfiguration ];
}
