{
  lib,
  inputs,
  config,
  build,
  variables,
  helpers,
  defs,
  funcs,
  common,
  host-files,
  nixosArchitectures,
}:

let
  inherit (common)
    processHostProfile
    ;

  buildVmConfiguration =
    {
      profileName,
      arch,
      buildArch ? arch,
    }:
    let
      processResult = processHostProfile {
        inherit profileName arch buildArch;
        isVirtual = true;
        overrides = {
          impermanence = false;
          deploymentMode = "managed";
          hardware = {
            cpu = null;
            gpu = null;
            board = null;
          };
          nixHardwareModule = null;
          wifiDeviceName = null;
          ethernetDeviceName = null;
          kernel = {
            bootModules = [ ];
            initrdModules = [ ];
            nixModules = [ ];
            extraModulePackages = [ ];
          };
          settings = {
            networking = {
              useNetworkManager = false;
              wifi.enabled = false;
            };
            system = {
              firmware = {
                redistributable = false;
                unfree = false;
              };
              touchpad.enabled = false;
            };
          };
        };
      };
      inherit (processResult) hostConfig buildContext;
      inherit (buildContext)
        system
        pkgs
        lib
        specialArgs
        buildArgs
        ;

      vmConfig = hostConfig.host.vm or { };
      isNiriDesktop = hostConfig.host.settings.system.desktop == "niri";
      mainUser = hostConfig.host.mainUser or null;
      mainUsername = if builtins.isAttrs mainUser then mainUser.username or null else null;
    in
    {
      name =
        if buildArch == arch then
          "${profileName}--${arch}--VIRTUAL"
        else
          "${profileName}--${arch}--${buildArch}--VIRTUAL";
      value = inputs.nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = specialArgs;
        modules = [
          (import (build + "/config/system/nixos.nix") buildArgs)
          inputs.sops-nix.nixosModules.sops
          inputs.disko.nixosModules.disko
          inputs.stylix.nixosModules.stylix
          inputs.nixvim.nixosModules.nixvim
        ]
        ++ lib.optionals isNiriDesktop [
          inputs.niri-flake.nixosModules.niri
          {
            programs.niri.package = lib.mkDefault pkgs.niri;
            niri-flake.cache.enable = false;
          }
        ]
        ++ [
          {
            assertions = [
              {
                assertion = hostConfig.host.allowVMBuild;
                message = "This profile is not allowed to run in a virtual machine!";
              }
            ];
          }
        ]
        ++ [
          {
            options.environment.persistence = lib.mkOption {
              type = lib.types.attrs;
              default = { };
              description = "Persistence configuration (dummy for VM builds)";
            };
            config = { };
          }
          (lib.mkIf (variables."nix-implementation" == "lix") {
            nix.package = lib.mkForce pkgs.lix;
          })
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.sharedModules = [
              inputs.sops-nix.homeManagerModules.sops
              inputs.nixvim.homeModules.nixvim
              (lib.mkIf (variables."nix-implementation" == "lix") {
                nix.package = lib.mkForce pkgs.lix;
              })
              {
                options.home.persistence = lib.mkOption {
                  type = lib.types.attrs;
                  default = { };
                  description = "Persistence configuration (dummy for VM builds)";
                };
                config = { };
              }
            ]
            ++ lib.optionals (!isNiriDesktop) [
              {
                options.programs.niri = lib.mkOption {
                  type = lib.types.attrs;
                  default = { };
                };
              }
            ];
            home-manager.useGlobalPkgs = false;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "nix-rebuild.backup";
            home-manager.extraSpecialArgs = specialArgs;
          }
          {
            virtualisation.vmVariant = {
              disko.enableConfig = lib.mkForce false;
              boot.initrd.kernelModules = [
                "virtio_pci"
                "9p"
                "9pnet_virtio"
              ];
              sops.age.keyFile = lib.mkForce "/tmp/shared/nx-vm/system/keys.txt";
              sops.age.sshKeyPaths = lib.mkForce [ ];
            }
            // lib.optionalAttrs (mainUsername != null) {
              home-manager.users.${mainUsername}.sops.age = {
                keyFile = lib.mkForce "/tmp/shared/nx-vm/user/keys.txt";
                sshKeyPaths = lib.mkForce [ ];
              };
            }
            // {
              virtualisation.memorySize = vmConfig.memorySize or 2048;
              virtualisation.cores = vmConfig.cores or 2;
              virtualisation.graphics = vmConfig.graphics or true;
            };
          }
        ]
        ++ (builtins.attrValues (
          builtins.mapAttrs (
            username: user:
            lib.mkIf (user.home-manager or false) {
              home-manager.users.${username} = import (build + "/config/home/home-integrated.nix") (
                buildArgs
                // {
                  user = user;
                }
              );
            }
          ) (lib.filterAttrs (_: user: user.home-manager or false) hostConfig.users)
        ));
      };
    };
in
{
  buildVmConfigurations = builtins.listToAttrs (
    lib.flatten (
      map (
        profileName:
        (map (arch: buildVmConfiguration { inherit profileName arch; }) nixosArchitectures)
        ++ (lib.flatten (
          map (
            arch:
            map (buildArch: buildVmConfiguration { inherit profileName arch buildArch; }) (
              lib.filter (b: b != arch) nixosArchitectures
            )
          ) nixosArchitectures
        ))
      ) host-files
    )
  );
}
