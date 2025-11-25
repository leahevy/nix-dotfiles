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
  name = "filetypes";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    baseExtensionMappings = {
      jinja2 = "markdown";
    };
    additionalExtensionMappings = { };

    baseFilenameMappings = {
    };
    additionalFilenameMappings = { };

    basePatterns = {
    };
    additionalPatterns = { };
  };

  configuration =
    context@{ config, options, ... }:
    let
      allExtensions = self.settings.baseExtensionMappings // self.settings.additionalExtensionMappings;
      allFilenames = self.settings.baseFilenameMappings // self.settings.additionalFilenameMappings;
      allPatterns = self.settings.basePatterns // self.settings.additionalPatterns;

      extensionsLua = lib.concatStringsSep ",\n    " (
        lib.mapAttrsToList (ext: ft: "[\"${ext}\"] = \"${ft}\"") allExtensions
      );
      filenamesLua = lib.concatStringsSep ",\n    " (
        lib.mapAttrsToList (name: ft: "[\"${name}\"] = \"${ft}\"") allFilenames
      );
      patternsLua = lib.concatStringsSep ",\n    " (
        lib.mapAttrsToList (pattern: ft: "[\"${pattern}\"] = \"${ft}\"") allPatterns
      );
    in
    {
      programs.nixvim.extraConfigLua = ''
        _G.nx_modules = _G.nx_modules or {}
        _G.nx_modules["99-filetypes"] = function()
          vim.filetype.add({
            extension = {
              ${extensionsLua}
            },

            filename = {
              ${filenamesLua}
            },

            pattern = {
              ${patternsLua}
            }
          })

          ${lib.concatStringsSep "\n        " (
            lib.mapAttrsToList (ext: ft: ''
              vim.api.nvim_create_autocmd({"BufEnter", "BufRead", "BufNewFile"}, {
                pattern = "*.${ext}",
                callback = function()
                  if vim.bo.buftype == "prompt" or vim.bo.buftype == "nofile" then
                    return
                  end
                  vim.bo.filetype = "${ft}"
                end
              })'') allExtensions
          )}

          ${lib.concatStringsSep "\n        " (
            lib.mapAttrsToList (name: ft: ''
              vim.api.nvim_create_autocmd({"BufEnter", "BufRead", "BufNewFile"}, {
                pattern = "*/${name}",
                callback = function()
                  if vim.bo.buftype == "prompt" or vim.bo.buftype == "nofile" then
                    return
                  end
                  local filename = vim.fn.expand("%:t")
                  if filename == "${name}" then
                    vim.bo.filetype = "${ft}"
                  end
                end
              })'') allFilenames
          )}

          ${lib.concatStringsSep "\n        " (
            lib.mapAttrsToList (pattern: ft: ''
              vim.api.nvim_create_autocmd({"BufEnter", "BufRead", "BufNewFile"}, {
                callback = function()
                  if vim.bo.buftype == "prompt" or vim.bo.buftype == "nofile" then
                    return
                  end
                  local filepath = vim.fn.expand("%:p")
                  if string.match(filepath, "${pattern}") then
                    vim.bo.filetype = "${ft}"
                  end
                end
              })'') allPatterns
          )}
        end
      '';
    };
}
