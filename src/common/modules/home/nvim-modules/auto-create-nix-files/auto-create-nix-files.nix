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
  name = "auto-create-nix-files";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/nvim-init/60-auto-create-nix-files.lua".text = ''
        vim.api.nvim_create_autocmd("BufNewFile", {
          pattern = "*.nix",
          callback = function()
            local template_path = "${defs.rootPath}/templates/modules/module.nix"
            local template_content = {}
            
            local file = io.open(template_path, "r")
            if file then
              for line in file:lines() do
                table.insert(template_content, line)
              end
              file:close()
              
              local current_file = vim.api.nvim_buf_get_name(0)
              local filename = vim.fn.fnamemodify(current_file, ":t:r")  -- Get basename without extension
              
              for i, line in ipairs(template_content) do
                if line:match('name = "<MODULE>"') then
                  template_content[i] = line:gsub('<MODULE>', filename)
                  break
                end
              end
              
              vim.api.nvim_buf_set_lines(0, 0, -1, false, template_content)
              
              for i, line in ipairs(template_content) do
                if line:match('description = ""') then
                  local pos = string.find(line, '""')
                  vim.api.nvim_win_set_cursor(0, {i, pos})
                  vim.cmd("startinsert")
                  break
                end
              end
            else
              vim.notify("Could not find template at: " .. template_path, vim.log.levels.ERROR)
            end
          end,
        })
      '';
    };
}
