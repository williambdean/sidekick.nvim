local Config = require("sidekick.config")

local M = {}

---@class sidekick.lsp.Status
---@field busy boolean
---@field kind "Normal" | "Error" | "Warning" | "Inactive"
---@field message? string

local status = {} ---@type table<integer, sidekick.lsp.Status>

---@param res sidekick.lsp.Status
---@type lsp.Handler
function M.on_status(err, res, ctx)
  if err then
    return
  end
  status[ctx.client_id] = vim.deepcopy(res)

  if res.message and (res.kind == "Error" or res.kind == "Warning") then
    local msg = "**Copilot:** " .. res.message
    if msg:find("not signed") then
      msg = msg .. "\nPlease use `:LspCopilotSignIn` to sign in."
    end
    require("sidekick.util").notify(msg, res.kind == "Error" and vim.log.levels.ERROR or vim.log.levels.WARN)
  end
end

---@param client vim.lsp.Client
function M.attach(client)
  client.handlers.didChangeStatus = M.on_status
end

---@param buf? integer
---@return sidekick.lsp.Status?
function M.get(buf)
  local client = Config.get_client(buf)
  return client and (status[client.id] or { busy = false, kind = "Normal" }) or nil
end

return M
