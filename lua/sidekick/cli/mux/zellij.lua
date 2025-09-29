local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Zellij: sidekick.cli.Muxer
local M = {}
setmetatable(M, require("sidekick.cli.mux"))

M.tpl = [[
layout {
    pane command="{cmd}" {
      borderless true
      focus true
      name "{name}"
      close_on_exit true
      {args}
   }
}
session_serialization false
]]

---@return sidekick.cli.Tool.spec?
function M:cmd()
  if vim.fn.executable("zellij") ~= 1 then
    Util.error("zellij executable not found on $PATH")
    return
  end

  local layout = M.tpl
  layout = layout:gsub("{cmd}", self.tool.cmd[1])
  layout = layout:gsub("{name}", self.tool.name)
  if #self.tool.cmd == 1 then
    layout = layout:gsub("{args}", "")
  else
    local args = vim.list_slice(self.tool.cmd, 2)
    layout = layout:gsub("{args}", "args " .. table.concat(
      vim.tbl_map(function(a)
        return ("%q"):format(a)
      end, args),
      " "
    )) --[[@as string]]
  end

  local layout_file = vim.fn.stdpath("state") .. "/sidekick-zellij-" .. self.session .. ".layout"
  vim.fn.writefile(vim.split(layout, "\n"), layout_file)

  return {
    cmd = { "zellij", "--layout", layout_file, "attach", "--create", self.session },
    env = {
      ZELLIJ = false,
      ZELLIJ_SESSION_NAME = false,
      ZELLIJ_PANE_ID = false,
    },
  }
end

function M.sessions()
  local ret = vim.system({ "zellij", "list-sessions", "-n" }, { text = true }):wait()
  if ret.code ~= 0 then
    return {}
  end
  local sessions = {} ---@type table<string,sidekick.cli.mux.Session>
  for _, line in ipairs(vim.split(ret.stdout, "\n", { plain = true })) do
    local session = line:match("^(sidekick .-) %[")
    if session then
      sessions[session] = {
        name = session,
        tool = session:match("sidekick ([^ ]+)") or "",
      }
    end
  end
  return sessions
end

return M
