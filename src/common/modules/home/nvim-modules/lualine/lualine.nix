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
  name = "lualine";

  defaults = {
    theme = "auto";
    powerlineSymbols = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.lualine = {
        enable = true;
        settings = {
          options = {
            theme = self.settings.theme;
            component_separators =
              if self.settings.powerlineSymbols then
                {
                  left = "";
                  right = "";
                }
              else
                {
                  left = "|";
                  right = "|";
                };
            section_separators =
              if self.settings.powerlineSymbols then
                {
                  left = "";
                  right = "";
                }
              else
                {
                  left = "";
                  right = "";
                };
            globalstatus = true;
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [
              "branch"
              "diff"
              "diagnostics"
            ];
            lualine_c = [ "filename" ];
            lualine_x = [
              "encoding"
              "fileformat"
              "filetype"
            ];
            lualine_y = [ "progress" ];
            lualine_z = [ "location" ];
          };
        };
      };
    };
}
