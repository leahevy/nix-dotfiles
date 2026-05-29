{
  config,
  pkgs,
  lib,
  variables,
  helpers,
  nx-repositories,
  ...
}:

{
  imports = [
    ./live-common.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
        (pyFinal: pyPrev: {
          ipython = pyPrev.ipython.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_stream_performance"
            ];
          });
          nbmake = pyPrev.nbmake.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_when_import_error_then_fails"
            ];
          });
          proxy-py = pyPrev.proxy-py.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_empties_queue"
              "test_subscribe"
              "test_publish"
              "test_unsubscribe"
              "test_event_subscriber"
            ];
          });
          aiohttp = pyPrev.aiohttp.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [
              "test_cookie_pattern_performance"
              "test_regex_performance"
              "test_secure_https_proxy_absolute_path[pyloop-http]"
              "test_secure_https_proxy_absolute_path[pyloop-https]"
            ];
          });
        })
      ];
    })
  ];

  sdImage.compressImage = false;

  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0"
    "pcie_aspm=off"
  ];

  environment.systemPackages = [ pkgs.raspberrypi-eeprom ];
}
