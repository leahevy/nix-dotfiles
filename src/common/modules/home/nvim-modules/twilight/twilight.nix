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
  name = "twilight";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    autoEnable = true;
    context = 25;
    useTreesitter = true;
    expand = [
      "function"
      "method"
      "table"
      "if_statement"
      "else_clause"
      "for_statement"
      "for_loop"
      "while_statement"
      "while_loop"
      "do_while_statement"
      "switch_statement"
      "match_statement"
      "case_clause"
      "class_declaration"
      "class_definition"
      "struct_declaration"
      "enum_declaration"
      "interface_declaration"
      "try_statement"
      "catch_clause"
      "finally_clause"
      "block_statement"
      "compound_statement"
      "object_expression"
      "array_expression"
      "constructor_declaration"
      "lambda_expression"
      "arrow_function"
      "variable_declaration"
      "type_declaration"
      "namespace_declaration"
      "module_declaration"
      "package_declaration"
      "import_statement"
      "export_statement"
      "return_statement"
      "assignment_expression"
      "dictionary_expression"
      "trait_declaration"
      "union_declaration"
      "typedef_declaration"
      "macro_definition"
      "let_expression"
      "with_expression"
      "inherit_expression"
      "binding"
      "function_definition"
      "class_definition"
      "async_function_definition"
      "decorated_definition"
      "with_statement"
      "for_statement"
      "while_statement"
      "if_statement"
      "elif_clause"
      "else_clause"
      "except_clause"
      "finally_clause"
      "impl_item"
      "mod_item"
      "use_declaration"
      "fn_item"
      "struct_item"
      "enum_item"
      "trait_item"
      "impl_block"
      "match_expression"
      "closure_expression"
      "block_mapping"
      "block_sequence"
      "flow_mapping"
      "flow_sequence"
      "mapping_pair"
      "command_substitution"
      "pipeline"
      "command"
      "function_def"
      "compound_command"
      "subshell"
      "case_statement"
      "case_item"
      "begin_block"
      "end_block"
      "begin_statement"
      "end_statement"
      "do_block"
      "end_do"
      "if_statement"
      "function_item"
      "impl_item"
      "struct_item"
      "enum_item"
      "trait_item"
      "const_item"
      "static_item"
      "type_item"
      "macro_definition"
      "macro_invocation"
      "associated_type"
      "where_clause"
      "lifetime"
      "extern_crate_declaration"
      "message_body"
      "message"
      "service"
      "service_body"
      "rpc"
      "rpc_body"
      "field"
      "enum_body"
      "enum_value"
      "oneof"
      "oneof_body"
      "oneof_field"
      "option"
      "extend"
      "extensions"
      "reserved"
      "map_field"
      "group"
      "package"
      "syntax"
    ];
    exclude = [
      "markdown"
      "vimwiki"
      "help"
      "dashboard"
      "alpha"
      "startify"
      "NvimTree"
      "neo-tree"
      "netrw"
      "telescope"
      "TelescopePrompt"
      "TelescopeResults"
      "Trouble"
      "lazy"
      "mason"
      "notify"
      "toggleterm"
      "terminal"
      "qf"
      "quickfix"
      "man"
      "lspinfo"
      "checkhealth"
      "gitcommit"
      "gitrebase"
      "fugitive"
      "Codewindow"
      "popup"
      "prompt"
      "nofile"
      "nowrite"
      "yazi"
      ""
    ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.twilight = {
          enable = true;
          settings = {
            context = self.settings.context;
            treesitter = self.settings.useTreesitter;
            expand = self.settings.expand;
            exclude = self.settings.exclude;
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>k";
            action = "<cmd>Twilight<cr>";
            options = {
              desc = "Toggle focus mode";
              silent = true;
            };
          }
        ];

        autoCmd = lib.mkIf self.settings.autoEnable [
          {
            event = [
              "VimEnter"
              "BufEnter"
              "BufRead"
              "BufNewFile"
              "FileType"
              "WinEnter"
            ];
            callback.__raw = ''
              function()
                local excluded_filetypes = {
                  ${lib.concatMapStringsSep ", " (ft: "\"${ft}\"") self.settings.exclude}
                }

                local function is_excluded()
                  local ft = vim.bo.filetype
                  for _, excluded_ft in ipairs(excluded_filetypes) do
                    if ft == excluded_ft then
                      return true
                    end
                  end
                  return false
                end

                if not is_excluded() then
                  vim.defer_fn(function()
                    require("twilight").enable()
                  end, 100)
                end
              end
            '';
          }
        ];
      };

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<leader>k";
              desc = "Toggle focus mode";
              icon = "🎯";
            }
          ];
    };
}
