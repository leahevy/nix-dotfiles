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
  name = "raspberrypi";

  group = "system";
  input = "build";

  module = {
    linux.init =
      config:
      lib.mkIf config.nx.common.dev.agents.enable {
        nx.common.dev.agents.skills."raspberry-pi-config" = {
          description = "Add or modify Raspberry Pi firmware config, dtparams, dtoverlays, or kernel boot parameters.";
          text = ''
            # Raspberry Pi Config Changes

            ## Precondition

            NXCore lives at `~/.config/nx/nxcore`. Before doing anything else, check
            that this directory exists. If it does not, tell the user: "This skill is
            not applicable on this machine - `~/.config/nx/nxcore` does not exist."
            Then stop; do not proceed with any of the steps below.

            All paths below are relative to `~/.config/nx/nxcore`.

            Two separate files handle Pi configuration. Never mix them:

            - `~/.config/nx/nxcore/src/build/config/system/raspberrypi.nix`: infrastructure only (imports, bootloader type, assertions using host.*). No module-system access.
            - `~/.config/nx/nxcore/src/build/modules/system/raspberrypi.nix`: all NixOS option-setting (kernel params, dtparams, dtoverlays, journal-watcher ignores). Full module function access.

            Never add nx.* options, self.* calls, or module.enabled blocks to `~/.config/nx/nxcore/src/build/config/system/raspberrypi.nix`.

            ## config.txt via nixos-raspberrypi

            All config.txt settings go via `hardware.raspberry-pi.config`. Top-level key is a filter section (use `all` unless hardware-model-specific):

            ```nix
            hardware.raspberry-pi.config.all = {
              options."arm_boost" = { enable = true; value = true; };          # key=value lines
              base-dt-params."pciex1_gen" = { enable = true; value = 2; };     # dtparam= lines
              dt-overlays."pciex1-compat-pi5" = {
                enable = true;
                params.no-mip.enable = true;
              };
            };
            ```

            Use `hardware.raspberry-pi.extra-config` for raw verbatim lines only when the structured API cannot express the setting.

            ## Kernel boot parameters

            Go in `boot.kernelParams` inside `module.linux.system` (NOT in config/raspberrypi.nix).

            ## Finding valid dtparam and overlay names

            Always verify names against `/boot/firmware/overlays/README` on the running Pi before adding. Invalid names are silently ignored by firmware.

            In the README: plain indented lines under an overlay = base dtparams (use `base-dt-params`). Lines under a `Name:` header with `Load: dtoverlay=...` = named overlays (use `dt-overlays`).

            ## Inspecting the nixos-raspberrypi flake source

            The input is available at `/etc/nx/inputs/nixos-raspberrypi/`. Key files:
            - `modules/configtxt-config.nix`: option type definitions (field names and types)
            - `modules/configtxt.nix`: default values and examples
          '';
        };
      };

    linux.system = config: {
      nix.settings.max-jobs = 1;
      nix.settings.cores = 2;

      systemd.services.nix-daemon.serviceConfig.CPUQuota = "80%";

      powerManagement.cpuFreqGovernor = "performance";

      boot.kernelParams = [
        "nvme_core.default_ps_max_latency_us=0"
        "pcie_aspm=off"
        "pcie_port_pm=off"
        "nvme_core.io_timeout=255"
        "nvme_core.max_retries=10"
      ];

      boot.loader.raspberry-pi.configurationLimit = 15;

      hardware.raspberry-pi.config.all = {
        base-dt-params.pciex1_no_l0s = {
          enable = true;
          value = "on";
        };
        base-dt-params.pciex1_gen = {
          enable = true;
          value = 1;
        };
        dt-overlays."pciex1-compat-pi5" = {
          enable = true;
          params = {
            no-mip.enable = true;
            no-l0s.enable = true;
            mmio-hi.enable = true;
          };
        };
      };
    };

    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          kernel = true;
          string = "nvme nvme0: min host memory \\([0-9]+ MiB\\) above limit \\(0 MiB\\)\\.";
        }
        {
          kernel = true;
          string = "genirq: irq_chip rp1_irq_chip did not update eff\\. affinity mask of irq [0-9]+";
        }
        {
          kernel = true;
          string = "platform axi:gpu: deferred probe pending: \\(reason unknown\\)";
        }
        {
          kernel = true;
          string = "BTRFS warning \\(device dm-[0-9]+\\): read-write for sector size [0-9]+ with page size [0-9]+ is experimental";
        }
        {
          kernel = true;
          string = "hci_uart_bcm serial[0-9]+-[0-9]+: supply v(bat|ddio) not found, using dummy regulator";
        }
        {
          kernel = true;
          string = "nvme nvme0: using unchecked data buffer";
        }
        {
          kernel = true;
          string = "memcpy: detected field-spanning write.*fweh\\.c";
        }
        {
          kernel = true;
          string = "WARNING: CPU: [0-9]+ PID: [0-9]+ at .*/brcmfmac/fweh\\.c.*";
        }
        {
          string = "device \\(p2p-dev-wlan0\\): error setting IPv4 forwarding to '1': Resource temporarily unavailable";
        }
        {
          service = "NetworkManager.service";
          tag = "NetworkManager";
          string = "device \\(p2p-dev-wlan0\\): error setting IPv4 forwarding to '1': Success";
        }
      ];
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.regularHealthChecks = {
          "!35 - CPU throttled" = ''
            _out=$(${
              helpers.packageFile args pkgs.libraspberrypi "bin/vcgencmd"
            } get_throttled 2>/dev/null || true)
            [[ -n "$_out" ]] || exit 0
            _hex=$(printf '%s' "$_out" | ${pkgs.gnused}/bin/sed 's/throttled=//')
            if [[ "$_hex" =~ ^0x[0-9A-Fa-f]+$ ]]; then
              _dec=$(( _hex ))
              if [[ $(( _dec & 0xF )) -ne 0 ]]; then
                printf '%s\n' "$_hex" >&3
              fi
              if [[ $(( _dec & 0xF )) -ne 0 ]]; then
                exit 1
              fi
            fi
          '';
        };
      };
    };
  };
}
