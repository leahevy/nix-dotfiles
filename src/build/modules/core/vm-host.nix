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
  name = "vm-host";

  group = "core";
  input = "build";

  disableOnVM = true;

  module = {
    enabled = config: {
      nx.commandline.vm =
        cmds:
        let
          inherit (cmds)
            option
            optionWith
            optionWithDefault
            optionWithEnum
            architectures
            ;
        in
        {
          description = "Build and run a NixOS VM";
          group = "switch";
          scope = "integrated";
          system = "linux";
          modes = [
            "develop"
            "local"
          ];
          options = {
            timeout = optionWithDefault "Set timeout in seconds" "seconds" "int" "7200";
            profile = optionWith "Use specific profile" "profile" "string";
            arch = optionWithEnum "Target architecture for cross-arch builds" "architecture" architectures;
            show-trace = option "Show detailed Nix error traces";
            allow-ifd = option "Allow import-from-derivation";
            skip-verification = option "Skip commit signature verification";
            keep = option "Save VM image with timestamp instead of using ephemeral storage";
            no-run = option "Build VM image without starting it";
            reuse-latest = option "Run the most recently saved image without rebuilding";
            select = optionWith "Run a specific saved image by version name" "version" "string";
            list = option "List all saved VM images for the current profile";
            list-all = option "List all saved VM images for all profiles";
            cleanup = option "Remove all cached VM images for the current profile";
            cleanup-all = option "Remove all cached VM images for all profiles";
            age-system-file = optionWith "Use system age key from file path (no sudo)" "system_path" "filepath";
            age-user-file = optionWith "Use user age key from file path (no sudo)" "user_path" "filepath";
            age-file = optionWith "Use same age key file for both system+user (no sudo)" "path" "filepath";
            no-user-age = option "Skip passing a user age key to the VM";
            dangerously-use-host-sops = option "Allow copying host SOPS age key into VM share via sudo";
          };
        };
    };
    system =
      config:
      lib.mkIf self.host.settings.system.virtualisation.enableKVM {
        boot.kernelModules =
          lib.optional (self.host.hardware.cpu == "intel") "kvm-intel"
          ++ lib.optional (self.host.hardware.cpu == "amd") "kvm-amd";

        environment.systemPackages = with pkgs; [
          qemu
          OVMF
        ];
      };
    home =
      { config, ... }:
      {
        home.shellAliases.get-ovmf-code = "echo ${pkgs.OVMF.fd}/FV/OVMF.fd";

        programs.fish.functions = {
          vm-image-create = ''
            argparse 'n/name=' 's/size=' -- $argv
            or return

            if not set -q _flag_name
              echo "Usage: vm-image-create --name NAME [--size SIZE]"
              return 1
            end

            set -q _flag_size; or set _flag_size 40G
            set image_path "$HOME/.cache/nx/vms/qemu-images/$_flag_name.qcow2"
            mkdir -p "$HOME/.cache/nx/vms/qemu-images"
            if test -e "$image_path"
              echo "Image already exists: $image_path"
              return 1
            end
            ${pkgs.qemu}/bin/qemu-img create -f qcow2 "$image_path" "$_flag_size"
          '';

          vm-run-bios = ''
            argparse 'n/name=' 'i/iso=' 'm/mem=' 'c/cpus=' 'p/ssh-port=' 'g/graphical' -- $argv
            or return

            if not set -q _flag_name
              echo "Usage: vm-run-bios --name NAME [--iso PATH] [--mem MiB] [--cpus N] [--ssh-port PORT] [--graphical]"
              return 1
            end

            set -q _flag_mem; or set _flag_mem 4096
            set -q _flag_cpus; or set _flag_cpus 4
            set -q _flag_ssh_port; or set _flag_ssh_port 2222
            set image_path "$HOME/.cache/nx/vms/qemu-images/$_flag_name.qcow2"

            if not test -f "$image_path"
              echo "Missing image: $image_path"
              echo "Create it first: vm-image-create --name $_flag_name"
              return 1
            end

            set cmd ${pkgs.qemu}/bin/qemu-system-x86_64 \
              ${lib.optionalString self.host.settings.system.virtualisation.enableKVM "-enable-kvm"} \
              -m "$_flag_mem" \
              -smp "$_flag_cpus" \
              -drive "file=$image_path,if=virtio" \
              -netdev "user,id=net0,hostfwd=tcp::$_flag_ssh_port-:22" \
              -device virtio-net-pci,netdev=net0

            if set -q _flag_iso
              set cmd $cmd -cdrom "$_flag_iso" -boot d
            end

            if not set -q _flag_graphical
              set cmd $cmd -nographic
            end

            $cmd
          '';

          vm-run-uefi = ''
            argparse 'n/name=' 'i/iso=' 'm/mem=' 'c/cpus=' 'p/ssh-port=' 'o/ovmf=' 'g/graphical' -- $argv
            or return

            if not set -q _flag_name
              echo "Usage: vm-run-uefi --name NAME [--iso PATH] [--mem MiB] [--cpus N] [--ssh-port PORT] [--ovmf PATH] [--graphical]"
              return 1
            end

            set -q _flag_mem; or set _flag_mem 4096
            set -q _flag_cpus; or set _flag_cpus 4
            set -q _flag_ssh_port; or set _flag_ssh_port 2222
            set -q _flag_ovmf; or set _flag_ovmf "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd"
            set image_path "$HOME/.cache/nx/vms/qemu-images/$_flag_name.qcow2"
            set vars_path "$HOME/.cache/nx/vms/qemu-images/$_flag_name.OVMF_VARS.fd"

            if not test -f "$image_path"
              echo "Missing image: $image_path"
              echo "Create it first: vm-image-create --name $_flag_name"
              return 1
            end

            if not test -f "$vars_path"
              cp "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd" "$vars_path"
              chmod 600 "$vars_path"
            end

            set cmd ${pkgs.qemu}/bin/qemu-system-x86_64 \
              ${lib.optionalString self.host.settings.system.virtualisation.enableKVM "-enable-kvm"} \
              -m "$_flag_mem" \
              -smp "$_flag_cpus" \
              -drive "file=$image_path,if=virtio" \
              -drive "if=pflash,format=raw,readonly=on,file=$_flag_ovmf" \
              -drive "if=pflash,format=raw,file=$vars_path" \
              -netdev "user,id=net0,hostfwd=tcp::$_flag_ssh_port-:22" \
              -device virtio-net-pci,netdev=net0

            if set -q _flag_iso
              set cmd $cmd -cdrom "$_flag_iso" -boot d
            end

            if not set -q _flag_graphical
              set cmd $cmd -nographic
            end

            $cmd
          '';
        };

        home.persistence."${self.persist}".directories = [
          ".cache/nx/vms"
        ];
      };
  };
}
