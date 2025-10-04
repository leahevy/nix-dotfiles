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
  name = "opengl";

  assertions = [
    {
      assertion =
        (self.user.isStandalone or false) || (self.host.isModuleEnabled or (x: false)) "graphics.opengl";
      message = "For integrated users: Requires linux.graphics.opengl system module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.persistence."${self.persist}" = {
        directories = [
          ".cache/mesa_shader_cache"
          ".cache/mesa_shader_cache_db"
        ];
      };
    };
}
