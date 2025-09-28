---@class sidekick.cli.Context
---@field buf integer
local M = {}

local CTRL_V = vim.keycode("<C-V>")

---@class sidekick.context.Location
---@field buf? integer
---@field name? string
---@field row? integer (1-based)
---@field col? integer (0-based)
---@field range? {from: sidekick.Pos, to: sidekick.Pos, kind: "line"|"char"} (1,0)-based

---@param opts? sidekick.context.Location
function M.format_location(opts)
  opts = opts or {}
  assert(opts.buf or opts.name, "Either buf or name must be provided")

  local fname = opts.name or vim.api.nvim_buf_get_name(opts.buf or 0)
  fname = vim.fs.relpath(vim.uv.cwd() or ".", fname) or fname
  local loc = ""
  if opts.range then
    local from, to = opts.range.from, opts.range.to
    if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
      from, to = to, from
    end

    if opts.range.kind == "line" and from[1] == to[1] then
      loc = ("%d"):format(from[1])
    elseif opts.range.kind == "line" then
      loc = ("%d-%d"):format(from[1], to[1])
    elseif opts.range.kind == "char" and from[1] == to[1] then
      loc = ("%d:%d-%d"):format(from[1], from[2] + 1, to[2] + 1)
    elseif opts.range.kind == "char" then
      loc = ("%d:%d-%d:%d"):format(from[1], from[2] + 1, to[1], to[2] + 1)
    end
  elseif opts.row and opts.col then
    loc = ("%d:%d"):format(opts.row, opts.col + 1)
  elseif opts.row then
    loc = ("%d"):format(opts.row)
  end
  return ("@%s:%s"):format(fname, loc)
end

---@param buf? integer
function M.get_location(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  ---@type sidekick.context.Location
  local ctx = {
    buf = buf,
    row = vim.fn.line("."),
    col = vim.fn.col(".") - 1,
  }

  local mode = vim.fn.mode()
  if mode:match("^[vV]$") or mode == CTRL_V then
    vim.cmd("normal! " .. mode)

    local from = vim.api.nvim_buf_get_mark(buf, "<")
    local to = vim.api.nvim_buf_get_mark(buf, ">")
    if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
      from, to = to, from
    end
    ctx.range = { from = { from[1], from[2] }, to = { to[1], to[2] }, kind = mode == "V" and "line" or "char" }
    vim.fn.feedkeys("gv", "nx") -- restore visual selection
  end
  return M.format_location(ctx), ctx
end

---@param buf? integer
---@param opts? vim.diagnostic.GetOpts
function M.get_diagnostics(buf, opts)
  buf = buf or vim.api.nvim_get_current_buf()
  local diags = vim.diagnostic.get(buf, opts)
  if #diags == 0 then
    return
  end
  table.sort(diags, function(a, b)
    if a.lnum == b.lnum then
      return a.col < b.col
    end
    return a.lnum < b.lnum
  end)
  local ret = {} ---@type string[]
  for _, d in ipairs(diags) do
    ret[#ret + 1] = ("[%s] %s %s"):format(
      vim.diagnostic.severity[d.severity],
      d.message:gsub("\n", " "),
      M.format_location({
        buf = buf,
        range = { from = { d.lnum + 1, d.col }, to = { d.end_lnum + 1, d.end_col }, kind = "char" },
      })
    )
  end
  return table.concat(ret, "\n"), diags
end

return M
