local Config = require("sidekick.config")

local M = {}

---@class sidekick.lsp.Status
---@field busy boolean
---@field kind "Normal" | "Error" | "Warning" | "Inactive"
---@field message? string

local status = {} ---@type table<integer, sidekick.lsp.Status>

---@type lsp.Handler
function M._handler(err, res, ctx)
  if err then
    return
  end
  status[ctx.client_id] = vim.deepcopy(res)
  if res.status == "Error" then
    vim.notify("Please use `:LspCopilotSignIn` to sign in to Copilot", vim.log.levels.ERROR)
  end
end

---@param buf? integer
---@return sidekick.lsp.Status?
function M.get(buf)
  local client = Config.get_client(buf)
  return client and (status[client.id] or { busy = false, kind = "Normal" }) or nil
end

return M
