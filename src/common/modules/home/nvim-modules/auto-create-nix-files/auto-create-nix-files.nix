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
              
              vim.api.nvim_buf_set_lines(0, 0, -1, false, template_content)
              
              for i, line in ipairs(template_content) do
                if line:match('name = "<MODULE>"') then
                  vim.api.nvim_win_set_cursor(0, {i, string.find(line, '"<MODULE>"') + 1})
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
