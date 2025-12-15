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
  name = "bongocat";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  settings = {
    event = null;
    keyboardName = null;
    useKeydVirtual = false;
    output =
      if self.host ? displays && self.host.displays ? main then
        self.host.displays.main
      else if self.user ? displays && self.user.displays ? main then
        self.user.displays.main
      else
        null;
    package = pkgs-unstable.wayland-bongocat;
    xOffset = -280;
    yOffset = 30;
    catSize = 75;
  };

  configuration =
    context@{ config, options, ... }:
    let
      devicePath =
        if self.settings.event != null then
          self.settings.event
        else if self.settings.keyboardName != null then
          "/dev/input/by-id/usb-${
            builtins.replaceStrings [ " " ] [ "_" ] self.settings.keyboardName
          }-event-kbd"
        else if self.settings.useKeydVirtual then
          "auto-keyd"
        else
          null;

      findKeydScript = pkgs.writeShellScript "find-keyd-device" ''
        for device in /dev/input/event*; do
          device_name=$(cat /sys/class/input/$(basename "$device")/device/name 2>/dev/null || echo "")
          if [[ "$device_name" == *"keyd virtual keyboard"* ]]; then
            echo "$device"
            exit 0
          fi
        done
        exit 1
      '';

      configContent = ''
        cat_x_offset=${builtins.toString self.settings.xOffset}
        cat_y_offset=${builtins.toString self.settings.yOffset}
        cat_align=center

        cat_height=${builtins.toString self.settings.catSize}

        overlay_height=90
        overlay_opacity=0
        overlay_position=bottom
        layer=bottom

        idle_frame=0
        fps=30
        keypress_duration=120

        idle_sleep_timeout=10

        ${lib.optionalString (self.settings.output != null) "monitor=${self.settings.output}"}

        enable_debug=0
      '';

      startScript = pkgs.writeShellScript "bongocat-start" ''
        timeout=30
        while [ $timeout -gt 0 ] && [ -z "$WAYLAND_DISPLAY" ]; do
          echo "Waiting for Wayland display... ($timeout seconds left)"
          sleep 1
          timeout=$((timeout - 1))
        done

        if [ -z "$WAYLAND_DISPLAY" ]; then
          echo "ERROR: WAYLAND_DISPLAY not set after 30 seconds"
          exit 1
        fi

        echo "Wayland display: $WAYLAND_DISPLAY"

        ${
          if devicePath == "auto-keyd" then
            ''
              DEVICE=$(${findKeydScript})
              echo "Using keyd virtual keyboard: $DEVICE"
            ''
          else
            ''
              DEVICE="${devicePath}"
            ''
        }

        cat > ~/.config/bongocat.conf << EOF
        ${configContent}
        keyboard_device=$DEVICE
        EOF

        exec ${self.settings.package}/bin/bongocat --config ~/.config/bongocat.conf --watch-config
      '';
    in
    lib.mkIf (devicePath != null) {
      home.packages = [ self.settings.package ];

      systemd.user.services.nx-bongocat = {
        Unit = {
          Description = "Wayland Bongocat";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          OnFailure = [ ];
          Requisite = [ ];
          StartLimitIntervalSec = "600s";
          StartLimitBurst = 30;
        };

        Service = {
          Type = "exec";
          ExecStart = startScript;
          Restart = "on-failure";
          RestartSec = "5s";
          SuccessExitStatus = [
            0
            1
          ];
          RestartPreventExitStatus = [
            1
            2
          ];
          TimeoutStartSec = 15;
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

    };
}
