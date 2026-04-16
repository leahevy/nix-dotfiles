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
  name = "{{_file_name_}}";
  #description = "";

  group = "{{_lua:extract_group()_}}";
  input = "{{_lua:extract_input()_}}";

  # Attrset: { INPUT.GROUP = { MODULE = true or {...}; }; } or List: { INPUT.GROUP = [ "module1" "module2" ]; }
  submodules = { };

  # Defaults for self.settings, overridable from profile
  settings = { };

  # Typed options at config.nx.INPUT.GROUP.MODULE.*, access via (self.options config).NAME
  options = { };

  # Root-level NixOS/HM options
  rawOptions = { };

  # Unfree package names to allow
  unfree = [ ];

  # Arbitrary data, accessed via self.importFileCustom
  custom = { };

  # warning = "This module is work in progress.";
  # error = "This module is currently broken!";
  # broken = true;

  # Warn if built on wrong platform/arch
  # platforms = [ "linux" "darwin" ];
  # architectures = [ "x86_64" "aarch64" ];

  # Error if built on wrong platform/arch
  # requiredPlatforms = [ "linux" "darwin" ];
  # requiredArchitectures = [ "x86_64" "aarch64" ];

  assertions = [
    {
      assertion = true;
      message = "Test assertion";
    }
  ];

  module = {
    # All modules, both contexts, only config.nx.*, no self.settings
    # init = config: { };  # only config: allowed, not { config, ... }

    # Enabled only, both contexts (only config: allowed, not { config, ... })
    # enabled = config: { };

    # Enabled, home context (prefer { config, opt, ... } for direct option access; config: also allowed)
    home =
      { config, ... }:
      {
        home.persistence."${self.persist}" = {
          directories = [ ];
          files = [ ];
        };
      };

    # Enabled, system context
    # system = { config, ... }: {
    #   environment.persistence."${self.persist}" = {
    #     directories = [ ];
    #     files = [ ];
    #   };
    # };

    # standalone = { config, ... }: { };
    # integrated = { config, ... }: { };

    # Before pkgs creation, no pkgs access
    # overlays = [ (final: prev: { ... }) ];

    # linux = {
    #   overlays = [ (final: prev: { ... }) ];
    #   init = config: { };
    #   enabled = config: { };
    #   home = config: { };
    #   system = config: { };
    #   standalone = config: { };
    #   integrated = config: { };
    # };
    # darwin = { ... };

    # x86_64 = {
    #   overlays = [ (final: prev: { ... }) ];
    #   init = config: { };
    #   enabled = config: { };
    #   home = config: { };
    #   system = config: { };
    #   linux = { init = config: { }; home = config: { }; ... };
    #   darwin = { ... };
    # };
    # aarch64 = { ... };

    # moduleEnabled.INPUT.GROUP.MODULE = {
    #   enabled = config: { };
    #   home = config: { };
    #   system = config: { };
    #   standalone = config: { };
    #   integrated = config: { };
    #   linux = { enabled = config: { }; home = config: { }; ... };
    #   darwin = { ... };
    #   x86_64 = { home = config: { }; linux = { ... }; ... };
    #   aarch64 = { ... };
    # };
    # moduleDisabled.INPUT.GROUP.MODULE = { ... };

    # when = {
    #   condition = config: config.some.option == "value";
    #   modules.linux.notifications.pushover = true;                              # true=enabled, false=disabled
    #   modules.linux.notifications = [ "pushover" ];                             # list = all must be enabled
    #   modules.linux.notifications.pushover = { threshold = 3; };                # option checks (no implicit enable)
    #   modules.linux.notifications.pushover = { enable = true; threshold = 3; }; # explicit enable + options
    #   host.hostname = "host";                                                   # deep paths: host.kernel.variant = "lts"
    #   host.hostname = helpers.mkNot "host";                                     # invert: hostname != "host"
    #   user.username = "user";
    #   user.username = helpers.mkNot "user";                                     # invert: username != "user"
    #   option.threshold = 5;                                                     # this module's own option at config.nx.INPUT.GROUP.MODULE.*
    #   option.threshold = helpers.mkNot 0;                                       # invert: threshold != 0
    #   isNixOS = true;                                                           # isLinux isDarwin isX86_64 isAARCH64 isStandalone isIntegrated
    #   do = {
    #     home = config: { };
    #     linux = { home = config: { }; ... };
    #     x86_64.linux.home = config: { };
    #   };
    # };
    # when = [ { host.hostname = "host"; do.home = config: { }; } ];
  };
}
