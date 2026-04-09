{
  description = "NX Configuration";

  inputs = {
    # -----------------------------------------------------------------------------
    # Library inputs
    # -----------------------------------------------------------------------------

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "nix-systems";
    };

    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };

    nix-systems = {
      url = "github:nix-systems/default";
    };

    nix-systems-linux = {
      url = "github:nix-systems/default-linux";
    };

    nix-systems-darwin = {
      url = "github:nix-systems/default-darwin";
    };

    # -----------------------------------------------------------------------------
    # Forked inputs (require manual sync with upstream)
    # -----------------------------------------------------------------------------

    sops-nix = {
      url = "github:leahevy/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:leahevy/disko/v1.13.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:leahevy/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    lanzaboote = {
      url = "github:leahevy/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit.inputs.flake-compat.follows = "flake-compat";
    };

    niri-flake = {
      url = "github:leahevy/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:leahevy/nixos-hardware/master";
    };

    # -----------------------------------------------------------------------------
    # Local inputs
    # -----------------------------------------------------------------------------

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

    themes = {
      url = "path:./src/themes";
      flake = false;
    };

    overlays = {
      url = "path:./src/overlays";
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

    # -----------------------------------------------------------------------------
    # Core inputs
    # -----------------------------------------------------------------------------

    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.11";
    };

    nixpkgs-nix = {
      url = "github:NixOS/nixpkgs/nixos-25.11";
    };

    nixpkgs-darwin = {
      url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    };

    nixpkgs-unstable = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    # -----------------------------------------------------------------------------
    # Community inputs
    # -----------------------------------------------------------------------------

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.systems.follows = "nix-systems";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.systems.follows = "nix-systems";
      inputs.nuschtosSearch.inputs.nixpkgs.follows = "nixpkgs";
      inputs.nuschtosSearch.inputs.flake-utils.follows = "flake-utils";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -----------------------------------------------------------------------------
    # Third-party inputs (require manual review on update)
    # -----------------------------------------------------------------------------

    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
      inputs.systems.follows = "nix-systems-darwin";
      inputs.flake-utils.follows = "flake-utils";
      inputs.flake-compat.follows = "flake-compat";
      inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs-darwin";
      inputs.cl-nix-lite.inputs.nixpkgs.follows = "nixpkgs-darwin";
      inputs.cl-nix-lite.inputs.treefmt-nix.follows = "mac-app-util/treefmt-nix";
      inputs.cl-nix-lite.inputs.flake-parts.follows = "flake-parts";
      inputs.cl-nix-lite.inputs.systems.follows = "nix-systems";
    };

    nix-plist-manager = {
      url = "github:SushyDev/nix-plist-manager/main";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs.lib;

      variables-base = import ./variables.nix { inherit lib; };
      variables-config = import (inputs.config + "/variables.nix") { inherit lib; };
      variables = lib.recursiveUpdate variables-base (
        variables-config
        // {
          allowedUnfreePackages =
            variables-base.allowedUnfreePackages ++ (variables-config.allowedUnfreePackages or [ ]);
        }
      );
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
        themes = inputs.themes;
        overlays = inputs.overlays;
      }
      // configInputs;

      funcs = import (inputs.lib + "/funcs.nix") {
        inherit lib defs additionalInputs;
      };

      helpers = import (inputs.lib + "/helpers.nix") {
        inherit lib defs additionalInputs;
        buildSystem = builtins.currentSystem;
      };

      standalone-user-files = builtins.filter (name: !(lib.strings.hasPrefix "." name)) (
        builtins.attrNames (builtins.readDir (inputs.config + "/profiles/home-standalone"))
      );
      host-files = builtins.filter (name: !(lib.strings.hasPrefix "." name)) (
        builtins.attrNames (builtins.readDir (inputs.config + "/profiles/nixos"))
      );

      nixosArchitectures = import inputs.nix-systems-linux;
      darwinArchitectures = import inputs.nix-systems-darwin;
      allArchitectures = import inputs.nix-systems;

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

      isoConfigurations = isoBuilder.buildIsoConfigurations;
      nixosConfigurations = nixosBuilder.buildNixOSConfigurations;
      homeConfigurations = homeManagerBuilder.buildHomeConfigurations;
    };
}
