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
  name = "hardening";

  group = "system";
  input = "build";

  disableOnTestingVM = true;

  module = {
    system =
      config:
      let
        filesystem = {
          "fs.protected_fifos" = 2;
          "fs.protected_hardlinks" = 1;
          "fs.protected_regular" = 2;
          "fs.protected_symlinks" = 1;
        };
        kernel = {
          "kernel.dmesg_restrict" = 1;
          "kernel.kptr_restrict" = 2;
          "kernel.unprivileged_bpf_disabled" = 1;
          "kernel.yama.ptrace_scope" = 1;
        };
        headlessKernel =
          lib.optionalAttrs
            (helpers.isDeploymentMode self [
              "server"
              "managed"
            ])
            {
              "dev.tty.ldisc_autoload" = 0;
              "kernel.perf_event_paranoid" = 3;
              "kernel.yama.ptrace_scope" = 2;
              "net.core.bpf_jit_harden" = 2;
            };
        hasResumeDevice =
          self.host.kernel.resumeDevice != null
          || helpers.getDiskoResumeDevices (config.disko.devices or { }) != [ ];
        hibernateActive = self.host.kernel.allowResume && hasResumeDevice;
      in
      {
        boot.kernel.sysctl =
          filesystem
          // kernel
          // headlessKernel
          // lib.optionalAttrs hibernateActive { "kernel.kexec_load_disabled" = 1; };
        security.protectKernelImage = lib.mkIf (!hibernateActive) true;
      };
  };
}
