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
  name = "raspberrypi";

  group = "system";
  input = "build";

  module = {
    linux.system = config: {
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
              if [[ $(( _dec & 0xF000F )) -ne 0 ]]; then
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
