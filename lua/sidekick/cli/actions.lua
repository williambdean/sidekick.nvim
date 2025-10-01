---@alias sidekick.cli.Action fun(terminal: sidekick.cli.Terminal)
---@type table<string, sidekick.cli.Action>
local M = {}

function M.prompt(t)
  local Cli = require("sidekick.cli")
  Cli.prompt(function(prompt)
    vim.schedule(function()
      vim.cmd.startinsert()
    end)
    local text = prompt and Cli.render({ prompt = prompt })
    if text then
      t:send(text)
    end
  end)
end

return M
