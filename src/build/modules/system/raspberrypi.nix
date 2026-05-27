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

  condition = true;

  module = {
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
      ];
    };
  };
}
