local M = {}

---@param opts? copilot.Config
function M.setup(opts)
  require("copilot.config").setup(opts)
end

function M.clear()
  require("copilot.nes").clear()
end

return M
