local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.Terminal
---@field tool sidekick.cli.Tool
---@field group integer
---@field ctime integer
---@field atime integer
---@field closed? boolean
---@field timer? uv.uv_timer_t
---@field send_queue string[]
---@field job? integer
---@field buf? integer
---@field win? integer
local M = {}
M.__index = M

local INITIAL_SEND_DELAY = 2000 -- ms
local SEND_DELAY = 100 --ms

M.terminals = {} ---@type table<string, sidekick.cli.Terminal>

---@generic T: table
---@param ... T
---@return T
local function merge(...)
  return vim.tbl_deep_extend("force", ...)
end

---@type vim.wo
local wo = {
  winhighlight = "Normal:SidekickChat,NormalNC:SidekickChat",
  cursorcolumn = false,
  cursorline = false,
  colorcolumn = "",
  fillchars = "eob: ",
  list = false,
  listchars = "tab:  ",
  number = false,
  relativenumber = false,
  signcolumn = "no",
  spell = false,
  winbar = "",
  statuscolumn = "",
  wrap = false,
  sidescrolloff = 0,
}

---@type vim.bo
local bo = {
  swapfile = false,
}

---@param name string
function M.get(name)
  return M.terminals[name]
end

---@param tool sidekick.cli.Tool
function M.new(tool)
  local self = setmetatable({}, M)
  self.tool = tool
  self.ctime = vim.uv.hrtime()
  self.atime = self.ctime
  self.send_queue = {}
  self.group = vim.api.nvim_create_augroup("sidekick_cli_" .. tool.name, { clear = true })
  M.terminals[self.tool.name] = self
  return self
end

function M:is_running()
  return self.job and vim.fn.jobwait({ self.job }, 0)[1] == -1
end

function M:start()
  if self:is_running() then
    return
  end
  self.buf = vim.api.nvim_create_buf(false, true)
  for k, v in pairs(merge(vim.deepcopy(bo), Config.cli.win.bo)) do
    ---@diagnostic disable-next-line: no-unknown
    vim.bo[self.buf][k] = v
  end
  vim.b[self.buf].sidekick_cli = self.tool.name

  local Actions = require("sidekick.cli.actions")

  for name, km in pairs(Config.cli.win.keys) do
    if type(km) == "table" then
      local lhs, rhs = km[1], km[2] or name
      ---@type sidekick.cli.Action?
      local action = type(rhs) == "function" and rhs or nil
      if type(rhs) == "string" then
        action = Actions[rhs] -- global actions
          or M[rhs] -- terminal methods
          or (vim.fn.exists(":" .. rhs) > 0 and function()
            vim.cmd[rhs]()
          end)
      end

      if not lhs then
        Util.error(("No lhs for keymap `%s`"):format(name))
      elseif not action then
        Util.error(("No action for keymap `%s`: %s"):format(name, tostring(rhs)))
      else
        local km_opts = vim.deepcopy(km) ---@type vim.keymap.set.Opts
        ---@diagnostic disable-next-line: inject-field, no-unknown
        km_opts.mode, km_opts[1], km_opts[2] = nil, nil, nil
        km_opts.silent = km_opts.silent ~= false
        km_opts.buffer = self.buf
        km_opts.desc = km_opts.desc or ("Sidekick: %s"):format(name:gsub("^%l", string.upper))
        vim.keymap.set(km.mode or "t", lhs, function()
          action(self)
        end, km_opts)
      end
    end
  end

  self:open_win()

  vim.api.nvim_create_autocmd("BufEnter", {
    group = self.group,
    buffer = self.buf,
    callback = function()
      self.atime = vim.uv.hrtime()
      vim.schedule(function()
        if vim.api.nvim_get_current_buf() == self.buf then
          vim.cmd.startinsert()
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd("TermClose", {
    group = self.group,
    buffer = self.buf,
    callback = function()
      vim.schedule(function()
        self:close()
      end)
    end,
  })

  vim.api.nvim_buf_call(self.buf, function()
    self.job = vim.fn.jobstart(self.tool.cmd, {
      term = true,
      env = self.tool.env,
    })
  end)

  if self.job <= 0 then
    Util.error("Failed to run `" .. table.concat(self.tool.cmd, " ") .. "`")
    self:close()
    return
  end

  self.timer = vim.uv.new_timer()
  self.timer:start(INITIAL_SEND_DELAY, SEND_DELAY, function()
    local next = table.remove(self.send_queue, 1)
    if next then
      vim.schedule(function()
        if self:is_running() then
          vim.api.nvim_chan_send(self.job, next)
        end
      end)
    end
  end)
  if Config.cli.watch then
    require("sidekick.cli.watch").enable()
  end
end

function M:open_win()
  if self:is_open() or not self.buf then
    return
  end
  vim.api.nvim_win_call(0, function()
    local wincmd = {
      left = "H",
      bottom = "J",
      top = "K",
      right = "L",
    }

    local cmd = ("%s sbuffer %d | wincmd %s"):format(
      Config.cli.win.layout,
      self.buf,
      wincmd[Config.cli.win.position] or "L"
    )

    vim.cmd(cmd)
    self.win = vim.api.nvim_get_current_win()
    if Config.cli.win.layout == "vertical" then
      vim.api.nvim_win_set_width(self.win, Config.cli.win.width)
    else
      vim.api.nvim_win_set_height(self.win, Config.cli.win.height)
    end
  end)
  for k, v in pairs(merge(vim.deepcopy(wo), Config.cli.win.wo)) do
    ---@diagnostic disable-next-line: no-unknown
    vim.wo[self.win][k] = v
  end
end

function M:focus()
  self:show()
  if not self:is_running() then
    return self
  end
  vim.api.nvim_set_current_win(self.win)
  return self
end

function M:blur()
  if not self:is_focused() then
    return
  end
  vim.cmd.wincmd("p")
end

function M:is_focused()
  return self:is_open() and vim.api.nvim_get_current_win() == self.win
end

function M:show()
  self:start()
  if not self:is_running() then
    return
  end
  self:open_win()
  return self
end

function M:hide()
  if self:is_open() then
    vim.api.nvim_win_close(self.win, true)
    self.win = nil
  end
  return self
end

function M:close()
  M.terminals[self.tool.name] = nil
  if vim.tbl_isempty(M.terminals) then
    require("sidekick.cli.watch").disable()
  end
  if self.timer and not self.timer:is_closing() then
    self.timer:close()
    self.timer = nil
  end
  self.closed = true
  self:hide()
  if self:is_running() then
    vim.fn.jobstop(self.job)
    self.job = nil
  end
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_delete(self.buf, { force = true })
    self.buf = nil
  end
  pcall(vim.api.nvim_clear_autocmds, { group = self.group })
  pcall(vim.api.nvim_del_augroup_by_id, self.group)
  return self
end

function M:toggle()
  if self:is_open() then
    self:hide()
  else
    self:show()
  end
  return self
end

function M:is_open()
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

---@param input string
function M:send(input)
  self:show()
  if not self:is_running() then
    return
  end
  table.insert(self.send_queue, input)
end

function M:submit()
  if not self:is_running() then
    return
  end
  self:send("\r") -- Updated to use the send method
end

return M
