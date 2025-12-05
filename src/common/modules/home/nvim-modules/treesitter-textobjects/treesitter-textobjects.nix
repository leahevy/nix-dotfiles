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
  name = "treesitter-textobjects";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      nvim-modules = {
        treesitter = true;
      };
    };
  };

  settings = {
    setJumps = true;
    lookahead = true;
    includeSurroundingWhitespace = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.treesitter-textobjects = {
          enable = true;
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>Ff";
            action = "<cmd>lua if _G.safe_peek_definition then _G.safe_peek_definition('@function.outer') else vim.notify('LSP textobjects not available', vim.log.levels.WARN, {title = 'Peek Definition'}) end<CR>";
            options = {
              desc = "Peek function definition";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>FF";
            action = "<cmd>lua if _G.safe_peek_definition then _G.safe_peek_definition('@class.outer') else vim.notify('LSP textobjects not available', vim.log.levels.WARN, {title = 'Peek Definition'}) end<CR>";
            options = {
              desc = "Peek class definition";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>F";
            group = "Textobjects";
            icon = "󰌟";
          }
          {
            __unkeyed-1 = "<leader>Fn";
            desc = "Swap with next";
            icon = "󰌟";
          }
          {
            __unkeyed-1 = "<leader>Fp";
            desc = "Swap with previous";
            icon = "󰌟";
          }
          {
            __unkeyed-1 = "<leader>Ff";
            desc = "Peek function definition";
            icon = "󰈙";
          }
          {
            __unkeyed-1 = "<leader>FF";
            desc = "Peek class definition";
            icon = "󰈙";
          }
          {
            __unkeyed-1 = "]m";
            desc = "Next function start";
            icon = "󰊕";
          }
          {
            __unkeyed-1 = "[m";
            desc = "Previous function start";
            icon = "󰊕";
          }
          {
            __unkeyed-1 = "]M";
            desc = "Next function end";
            icon = "󰊕";
          }
          {
            __unkeyed-1 = "[M";
            desc = "Previous function end";
            icon = "󰊕";
          }
          {
            __unkeyed-1 = "]c";
            desc = "Next class start";
            icon = "󰠱";
          }
          {
            __unkeyed-1 = "[c";
            desc = "Previous class start";
            icon = "󰠱";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["50-treesitter-textobjects"] = function()
            local ok, ts_textobjects = pcall(require, "nvim-treesitter.configs")
            if ok then
              ts_textobjects.setup({
                textobjects = {
                  select = {
                    enable = true,
                    lookahead = ${if self.settings.lookahead then "true" else "false"},
                    include_surrounding_whitespace = ${
                      if self.settings.includeSurroundingWhitespace then "true" else "false"
                    },

                    keymaps = {
                      ["af"] = "@function.outer",
                      ["if"] = "@function.inner",
                      ["ac"] = "@class.outer",
                      ["ic"] = "@class.inner",
                      ["ap"] = "@parameter.outer",
                      ["ip"] = "@parameter.inner",
                      ["ab"] = "@block.outer",
                      ["ib"] = "@block.inner",
                      ["al"] = "@loop.outer",
                      ["il"] = "@loop.inner",
                      ["aa"] = "@assignment.outer",
                      ["ia"] = "@assignment.inner",
                      ["a="] = "@assignment.outer",
                      ["i="] = "@assignment.inner",
                      ["aC"] = "@comment.outer",
                      ["iC"] = "@comment.inner",
                    },

                    selection_modes = {
                      ["@parameter.outer"] = "v",
                      ["@function.outer"] = "V",
                      ["@class.outer"] = "V",
                      ["@assignment.outer"] = "v",
                      ["@block.outer"] = "V",
                      ["@loop.outer"] = "V",
                    },
                  },

                  move = {
                    enable = true,
                    set_jumps = ${if self.settings.setJumps then "true" else "false"},

                    goto_next_start = {
                      ["]m"] = "@function.outer",
                      ["]c"] = "@class.outer",
                      ["]p"] = "@parameter.inner",
                      ["]b"] = "@block.outer",
                      ["]l"] = "@loop.outer",
                      ["]a"] = "@assignment.outer",
                      ["]C"] = "@comment.outer",
                    },

                    goto_next_end = {
                      ["]M"] = "@function.outer",
                      ["]["] = "@class.outer",
                      ["]P"] = "@parameter.inner",
                      ["]B"] = "@block.outer",
                      ["]L"] = "@loop.outer",
                      ["]A"] = "@assignment.outer",
                    },

                    goto_previous_start = {
                      ["[m"] = "@function.outer",
                      ["[c"] = "@class.outer",
                      ["[p"] = "@parameter.inner",
                      ["[b"] = "@block.outer",
                      ["[l"] = "@loop.outer",
                      ["[a"] = "@assignment.outer",
                      ["[C"] = "@comment.outer",
                    },

                    goto_previous_end = {
                      ["[M"] = "@function.outer",
                      ["[]"] = "@class.outer",
                      ["[P"] = "@parameter.inner",
                      ["[B"] = "@block.outer",
                      ["[L"] = "@loop.outer",
                      ["[A"] = "@assignment.outer",
                    },
                  },

                  swap = {
                    enable = true,
                    swap_next = {
                      ["<leader>Fn"] = "@parameter.inner",
                      ["<leader>Fm"] = "@function.outer",
                      ["<leader>Fc"] = "@class.outer",
                      ["<leader>Fb"] = "@block.outer",
                    },
                    swap_previous = {
                      ["<leader>Fp"] = "@parameter.inner",
                      ["<leader>FM"] = "@function.outer",
                      ["<leader>FC"] = "@class.outer",
                      ["<leader>FB"] = "@block.outer",
                    },
                  },

                  lsp_interop = {
                    enable = true,
                    border = "none",
                    floating_preview_opts = {},
                  },
                },
              })
            end

            local ok_lsp_interop, lsp_interop = pcall(require, "nvim-treesitter.textobjects.lsp_interop")
            if ok_lsp_interop then
              local original_make_preview_callback = lsp_interop.make_preview_location_callback

              lsp_interop.make_preview_location_callback = function(query_string, query_group, context)
                local original_callback = original_make_preview_callback(query_string, query_group, context)

                return function(err, result, ...)
                  if err and (err.message and err.message:match("unknown node type") or err.code_name == "UnknownErrorCode") then
                    vim.notify("LSP server does not support definition lookup for this text object", vim.log.levels.WARN, {
                      title = "Peek Definition",
                      icon = "⚠️"
                    })
                    return
                  elseif err then
                    vim.notify("Failed to peek definition: " .. tostring(err.message or err), vim.log.levels.ERROR, {
                      title = "Peek Definition Error",
                      icon = "❌"
                    })
                    return
                  end

                  return original_callback(err, result, ...)
                end
              end

              _G.safe_peek_definition = function(textobject)
                lsp_interop.peek_definition_code(textobject)
              end
            end

            local ok_repeat, ts_repeat_move = pcall(require, "nvim-treesitter.textobjects.repeatable_move")
            if ok_repeat then
              vim.keymap.set({ "n", "x", "o" }, ":", ts_repeat_move.repeat_last_move_next)
              vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)

              vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
              vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
              vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
              vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })
            end
          end
        '';
      };
    };
}
