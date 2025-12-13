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
  name = "nvim-ufo";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  assertions = [
    {
      assertion = !self.settings.enableLspCapabilities || self.isModuleEnabled "nvim-modules.lsp";
      message = "nvim-ufo LSP capabilities require the lsp module to be enabled";
    }
    {
      assertion =
        !self.settings.enableTreesitterProvider || self.isModuleEnabled "nvim-modules.treesitter";
      message = "nvim-ufo treesitter provider requires the treesitter module to be enabled";
    }
  ];

  settings = {
    enableLspCapabilities = true;
    enablePeekFunctionality = false;
    enableCustomVirtText = true;
    enableTreesitterProvider = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.nvim-ufo = {
          enable = true;
          setupLspCapabilities = lib.mkIf (
            self.isModuleEnabled "nvim-modules.lsp" && self.settings.enableLspCapabilities
          ) self.settings.enableLspCapabilities;

          settings = lib.mkMerge [
            (lib.mkIf (self.isModuleEnabled "nvim-modules.treesitter" && self.settings.enableTreesitterProvider)
              {
                provider_selector = {
                  __raw = ''
                    function(bufnr, filetype, buftype)
                      return {'treesitter', 'indent'}
                    end
                  '';
                };
              }
            )

            (lib.mkIf self.settings.enableCustomVirtText {
              fold_virt_text_handler = {
                __raw = ''
                  function(virtText, lnum, endLnum, width, truncate)
                    local newVirtText = {}
                    local suffix = (' 󰁂 %d '):format(endLnum - lnum)
                    local sufWidth = vim.fn.strdisplaywidth(suffix)
                    local targetWidth = width - sufWidth
                    local curWidth = 0
                    for _, chunk in ipairs(virtText) do
                      local chunkText = chunk[1]
                      local chunkWidth = vim.fn.strdisplaywidth(chunkText)
                      if targetWidth > curWidth + chunkWidth then
                        table.insert(newVirtText, chunk)
                      else
                        chunkText = truncate(chunkText, targetWidth - curWidth)
                        local hlGroup = chunk[2]
                        table.insert(newVirtText, {chunkText, hlGroup})
                        chunkWidth = vim.fn.strdisplaywidth(chunkText)
                        if curWidth + chunkWidth < targetWidth then
                          suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
                        end
                        break
                      end
                      curWidth = curWidth + chunkWidth
                    end
                    table.insert(newVirtText, {suffix, 'MoreMsg'})
                    return newVirtText
                  end
                '';
              };
            })
          ];
        };

        opts = {
          foldcolumn = lib.mkForce "1";
          foldlevel = lib.mkForce 99;
          foldlevelstart = lib.mkForce 99;
          foldenable = lib.mkForce true;
        };

        keymaps = [
          {
            mode = "n";
            key = "zR";
            action.__raw = "require('ufo').openAllFolds";
            options = {
              desc = "Open all folds";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "zM";
            action.__raw = "require('ufo').closeAllFolds";
            options = {
              desc = "Close all folds";
              silent = true;
            };
          }
        ]
        ++ lib.optionals self.settings.enablePeekFunctionality [
          {
            mode = "n";
            key = "zK";
            action.__raw = ''
              function()
                local winid = require('ufo').peekFoldedLinesUnderCursor()
                if not winid then
                  vim.lsp.buf.hover()
                end
              end
            '';
            options = {
              desc = "Peek fold or hover";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec =
          lib.mkIf (self.isModuleEnabled "nvim-modules.which-key" && self.settings.enablePeekFunctionality)
            [
              {
                __unkeyed-1 = "zK";
                desc = "Peek fold or hover";
                icon = "👁️";
              }
            ];
      };
    };
}
