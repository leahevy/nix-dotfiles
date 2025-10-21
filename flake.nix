{
  description = "NX Configuration";

  inputs = {
    lib = {
      url = "path:./src/lib";
      flake = false;
    };

    common = {
      url = "path:./src/common";
      flake = false;
    };

    linux = {
      url = "path:./src/linux";
      flake = false;
    };

    darwin = {
      url = "path:./src/darwin";
      flake = false;
    };

    build = {
      url = "path:./src/build";
      flake = false;
    };

    groups = {
      url = "path:./src/groups";
      flake = false;
    };

    config = {
      url = "path:./src/nxconfig";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    };

    profile = {
      url = "path:./src/profile";
      flake = false;
    };

    nixpkgs = {
      url = "nixpkgs/nixos-25.05";
    };

    nixpkgs-unstable = {
      url = "nixpkgs/nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/v1.12.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs.lib;

      variables-base = import ./variables.nix { inherit lib; };
      variables-config = import (inputs.config + "/variables.nix") { inherit lib; };
      variables =
        variables-base
        // variables-config
        // {
          allowedUnfreePackages =
            variables-base.allowedUnfreePackages ++ (variables-config.allowedUnfreePackages or [ ]);
        };
      configInputs = inputs.config.configInputs or { };

      defs = import (inputs.lib + "/defs.nix") { inherit lib; };

      additionalInputs = {
        common = inputs.common;
        linux = inputs.linux;
        darwin = inputs.darwin;
        build = inputs.build;
        groups = inputs.groups;
        lib = inputs.lib;
        config = inputs.config;
        profile = inputs.profile;
      }
      // configInputs;

      funcs = import (inputs.lib + "/funcs.nix") {
        inherit lib defs additionalInputs;
      };

      helpers = import (inputs.lib + "/helpers.nix") {
        inherit lib defs additionalInputs;
      };

      standalone-user-files = builtins.filter (name: !(lib.strings.hasPrefix "." name)) (
        builtins.attrNames (builtins.readDir (inputs.config + "/profiles/home-standalone"))
      );
      host-files = builtins.filter (name: !(lib.strings.hasPrefix "." name)) (
        builtins.attrNames (builtins.readDir (inputs.config + "/profiles/nixos"))
      );

      nixosArchitectures = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      darwinArchitectures = [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      allArchitectures = nixosArchitectures ++ darwinArchitectures;

      generateNixOSProfiles =
        profileNames:
        lib.flatten (
          map (
            profileName:
            map (arch: {
              name = "${profileName}--${arch}";
              profileName = profileName;
              architecture = arch;
            }) nixosArchitectures
          ) profileNames
        );

      generateHomeStandaloneProfiles =
        profileNames:
        lib.flatten (
          map (
            profileName:
            map (arch: {
              name = "${profileName}--${arch}";
              profileName = profileName;
              architecture = arch;
            }) allArchitectures
          ) profileNames
        );

      evalConfigModule =
        {
          configPath,
          optionsPath,
        }:
        lib.evalModules {
          modules = [
            optionsPath
            configPath
          ];
        };

      common = import (inputs.build + "/builders/common.nix") {
        inherit lib inputs;
        config = inputs.config;
        build = inputs.build;
        inherit
          variables
          helpers
          defs
          funcs
          nixosArchitectures
          darwinArchitectures
          allArchitectures
          ;
      };

      nixosBuilder = import (inputs.build + "/builders/system/nixos.nix") {
        inherit lib inputs;
        config = inputs.config;
        build = inputs.build;
        inherit
          variables
          helpers
          defs
          funcs
          common
          host-files
          nixosArchitectures
          ;
      };

      homeManagerBuilder = import (inputs.build + "/builders/home/home-standalone.nix") {
        inherit lib inputs;
        config = inputs.config;
        build = inputs.build;
        inherit
          variables
          helpers
          defs
          funcs
          common
          standalone-user-files
          allArchitectures
          ;
      };

      isoBuilder = import (inputs.build + "/builders/iso/iso.nix") {
        inherit lib inputs;
        config = inputs.config;
        build = inputs.build;
        inherit
          variables
          helpers
          defs
          funcs
          common
          nixosArchitectures
          ;
      };

      registryBuilder = import (inputs.build + "/builders/registry.nix") {
        inherit lib inputs;
      };

      hosts = nixosBuilder.extractHosts;
      users = homeManagerBuilder.extractUsers;

      packages = lib.genAttrs allArchitectures (system: {
        default = inputs.nixpkgs.legacyPackages.${system}.emptyDirectory;
      });
    in
    {
      inherit
        hosts
        users
        packages
        variables
        allArchitectures
        nixosArchitectures
        darwinArchitectures
        defs
        ;

      inherit (inputs) nixpkgs nixpkgs-unstable;

      modules = registryBuilder.modules;
      isoConfigurations = isoBuilder.buildIsoConfigurations;
      nixosConfigurations = nixosBuilder.buildNixOSConfigurations;
      homeConfigurations = homeManagerBuilder.buildHomeConfigurations;
    };
}
