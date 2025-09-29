local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Tmux: sidekick.cli.Muxer
local M = {}
setmetatable(M, require("sidekick.cli.mux"))

---@return sidekick.cli.Tool.spec?
function M:cmd()
  if vim.fn.executable("tmux") ~= 1 then
    Util.error("tmux executable not found on $PATH")
    return
  end
  local cmd = { "tmux", "new", "-A", "-s", self.session }
  vim.list_extend(cmd, self.tool.cmd)
  return { cmd = cmd }
end

function M.sessions()
  local ret = vim.system({ "tmux", "list-sessions" }, { text = true }):wait()
  if ret.code ~= 0 then
    return {}
  end
  local sessions = {} ---@type table<string,sidekick.cli.mux.Session>
  for _, line in ipairs(vim.split(ret.stdout, "\n", { plain = true })) do
    local session = line:match("^(sidekick .-):")
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
