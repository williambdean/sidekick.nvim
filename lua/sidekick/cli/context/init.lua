local Config = require("sidekick.config")

local M = {}

---@class sidekick.context.ctx
---@field win integer
---@field buf integer
---@field cwd string
---@field row integer (1-based)
---@field col integer (1-based)
---@field range? sidekick.context.Range

---@class sidekick.context.Range
---@field from sidekick.Pos (1,0)-based
---@field to sidekick.Pos (1,0)-based
---@field kind "line"|"char"|"block"

---@class sidekick.context.location.Opts
---@field row? boolean
---@field col? boolean
---@field range? boolean

---@class sidekick.context.diagnostics.Opts: vim.diagnostic.GetOpts
---@field all? boolean

---@class sidekick.Context
---@field msg? string|string[]
---@field prompt? string
---@field diagnostics? sidekick.context.diagnostics.Opts|boolean
---@field location? sidekick.context.location.Opts|boolean
---@field selection? boolean

---@type sidekick.Context
local prompt_defaults = {
  location = true,
}

function M.ctx()
  ---@param w integer
  local wins = vim.tbl_filter(function(w)
    local buf = vim.api.nvim_win_get_buf(w)
    return vim.bo[buf].filetype ~= "sidekick_terminal"
  end, vim.api.nvim_list_wins())
  table.sort(wins, function(a, b)
    return (vim.w[a].sidekick_visit or 0) > (vim.w[b].sidekick_visit or 0)
  end)

  if #wins == 0 then
    return
  end

  local win, buf = wins[1], vim.api.nvim_win_get_buf(wins[1])
  local cursor = vim.api.nvim_win_get_cursor(win)
  ---@type sidekick.context.ctx
  return {
    win = win,
    buf = buf,
    cwd = vim.fs.normalize(vim.fn.getcwd(win)),
    row = cursor[1],
    col = cursor[2] + 1,
    range = M.selection(buf),
  }
end

---@param a string|string[]|nil
---@return string[]
local function strlist(a)
  return type(a) == "table" and a or { a }
end

---@param ctx? sidekick.context.ctx
---@param opts? sidekick.Context
function M.resolve(ctx, opts)
  opts = opts or {}
  if opts.prompt then
    local prompt = Config.cli.prompts[opts.prompt] or {} --[[@as sidekick.Prompt]]
    if type(prompt) == "function" then
      prompt = prompt(ctx)
    end
    prompt = type(prompt) == "string" and { msg = prompt } or prompt
    ---@cast prompt sidekick.Context
    if prompt then
      local msg = strlist(prompt.msg)
      vim.list_extend(msg, strlist(opts.msg))
      return vim.tbl_deep_extend(
        "force",
        vim.deepcopy(prompt_defaults),
        vim.deepcopy(prompt),
        vim.deepcopy(opts),
        { msg = msg }
      )
    end
  end
  return opts
end

---@param opts? sidekick.Context
function M.get(opts)
  local ctx = M.ctx()
  opts = M.resolve(ctx, opts)

  local ret = {} ---@type sidekick.Text[]

  if opts.location and ctx and vim.tbl_contains({ "", "help" }, vim.bo[ctx.buf].buftype) then
    local Loc = require("sidekick.cli.context.location")
    local loc_opts = opts.location == true and {} or opts.location --[[@as sidekick.context.location.Opts]]
    ---@cast ctx sidekick.context.Loc
    vim.list_extend(ret, Loc.get(ctx, loc_opts))
  end

  if opts.diagnostics then
    local Diag = require("sidekick.cli.context.diagnostics")
    local diag_opts = opts.diagnostics == true and {} or opts.diagnostics --[[@as sidekick.context.diagnostics.Opts]]
    vim.list_extend(ret, Diag.get(ctx, diag_opts) or {})
  end

  if opts.selection ~= false and ctx and ctx.range then
    local Selection = require("sidekick.cli.context.selection")
    if #ret > 0 then
      ret[#ret + 1] = { { "" } }
    end
    vim.list_extend(ret, Selection.get(ctx) or {})
    ret[#ret + 1] = { { "" } }
  end

  ---@diagnostic disable-next-line: assign-type-mismatch
  for _, m in ipairs(strlist(opts.msg)) do
    ret[#ret + 1] = { { m } }
  end

  local lines = require("sidekick.text").lines(ret)
  return table.concat(lines, "\n"), ret
end

---@param buf? integer
---@return sidekick.context.Range?
function M.selection(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()
  if not (mode:match("^[vV]$") or mode == "\22") then
    return
  end

  vim.cmd("normal! " .. mode)
  local kind = mode == "V" and "line" or mode == "v" and "char" or "block"
  local from = vim.api.nvim_buf_get_mark(buf, "<")
  local to = vim.api.nvim_buf_get_mark(buf, ">")
  if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
    from, to = to, from
  end

  ---@type sidekick.context.Range
  local ret = {
    from = { from[1], from[2] },
    to = { to[1], to[2] },
    kind = kind,
  }
  vim.fn.feedkeys("gv", "nx") -- restore visual selection
  return ret
end

return M
