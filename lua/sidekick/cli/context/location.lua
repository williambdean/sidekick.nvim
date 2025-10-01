local M = {}

---@class sidekick.context.Loc: sidekick.context.ctx
---@field name? string
---@field win? integer
---@field buf? integer

---@param ctx sidekick.context.Loc
---@param opts? sidekick.context.location.Opts
---@return sidekick.Text[]
function M.get(ctx, opts)
  opts = opts or {}
  assert(ctx.buf or ctx.name, "Either buf or name must be provided")

  local name = ctx.name or vim.api.nvim_buf_get_name(ctx.buf)
  if not name or name == "" then
    name = "[No Name]"
  else
    local ok, rel = pcall(vim.fs.relpath, ctx.cwd, name)
    if ok and rel and rel ~= "" and rel ~= "." then
      name = rel
    end
  end

  local ret = {} ---@type sidekick.Text
  if ctx.range and opts.range ~= false then
    local from, to = ctx.range.from, ctx.range.to
    if from[1] > to[1] or (from[1] == to[1] and from[2] > to[2]) then
      from, to = to, from
    end
    if ctx.range.kind == "line" and from[1] == to[1] then
      ret[#ret + 1] = { ("%d"):format(from[1]), "SnacksPickerRow" }
    elseif ctx.range.kind == "line" then
      ret[#ret + 1] = { ("%d-%d"):format(from[1], to[1]), "SnacksPickerRow" }
    elseif from[1] == to[1] then -- block/char on same line
      ret[#ret + 1] = { ("%d"):format(from[1]), "SnacksPickerRow" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { ("%d-%d"):format(from[2] + 1, to[2] + 1), "SnacksPickerCol" }
    else -- block/char on different lines
      ret[#ret + 1] = { ("%d"):format(from[1]), "SnacksPickerRow" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { ("%d-%d:%d"):format(from[2] + 1, to[1], to[2] + 1), "SnacksPickerCol" }
    end
  elseif opts.col ~= false and ctx.row and ctx.col then
    ret[#ret + 1] = { ("%d"):format(ctx.row), "SnacksPickerRow" }
    ret[#ret + 1] = { ":", "SnacksPickerDelim" }
    ret[#ret + 1] = { ("%d"):format(ctx.col), "SnacksPickerCol" }
  elseif opts.row ~= false and ctx.row then
    ret[#ret + 1] = { ("%d"):format(ctx.row), "SnacksPickerRow" }
  end

  if #ret > 0 then
    table.insert(ret, 1, { ":", "SnacksPickerDelim" })
  end
  table.insert(ret, 1, { name, "SnacksPickerDir" })
  table.insert(ret, 1, { "@", "Bold" })
  return { ret }
end

return M
