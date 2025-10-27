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
  name = "fastfetch";

  group = "shell";
  input = "common";
  namespace = "home";

  defaults = {
    logo = "NixOS_small";
    structure = "os:kernel:uptime:packages:shell:wm:terminal:memory:swap";
    otherArgs = "";
    addToShell = false;
  };

  configuration =
    context@{ config, options, ... }:
    lib.mkMerge [
      {
        home.packages = with pkgs; [
          fastfetch
        ];
      }
      (lib.mkIf self.settings.addToShell {
        home.file."${config.xdg.configHome}/fish-init/90-fastfetch.fish".text = ''
          echo
          fastfetch ${
            if self.settings.logo != "" then "--logo ${self.settings.logo}" else ""
          } --structure ${self.settings.structure} ${self.settings.otherArgs};
        '';
      })
    ];
}
