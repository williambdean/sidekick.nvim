local M = {}

---@param opts? sidekick.Config
function M.setup(opts)
  require("sidekick.config").setup(opts)
end

function M.clear()
  require("sidekick.nes").clear()
end

return M
