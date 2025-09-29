local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.mux.Session
---@field name string
---@field tool string

---@class sidekick.cli.Muxer
---@field tool sidekick.cli.Tool
---@field session string
local M = {}
M.__index = M

---@param tool sidekick.cli.Tool
function M.new(tool)
  local super = M.get()
  if not super then
    return
  end
  ---@type sidekick.cli.Muxer
  local self = setmetatable({}, { __index = super })
  self.tool = tool
  self.session = M.get_session(self.tool)
  return self
end

---@return sidekick.cli.Tool.spec?
function M:cmd()
  error("Muxer:cmd() not implemented")
end

---@return table<string,sidekick.cli.mux.Session>
function M.sessions()
  local mux = M.get()
  return mux and mux.sessions() or {}
end

---@param tool sidekick.cli.Tool
function M.get_session(tool)
  local cwd = vim.fn.getcwd(0)
  cwd = vim.fn.fnamemodify(cwd, ":p:~")
  cwd = cwd:gsub("[^%w%-%_~ ]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  return ("sidekick " .. tool.name .. " " .. cwd)
end

function M.get()
  if not Config.cli.mux.enabled then
    return
  end
  ---@type boolean, sidekick.cli.Muxer
  local ok, ret = pcall(require, "sidekick.cli.mux." .. Config.cli.mux.backend)
  if not ok then
    Util.error("Invalid **mux** backend `" .. Config.cli.mux.backend .. "`")
    return
  end
  return ret
end

return M
