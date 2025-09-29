local M = {}

---@param msg string
---@param level? vim.log.levels
function M.notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = "Sidekick" })
  end)
end

---@param msg string
function M.info(msg)
  M.notify(msg, vim.log.levels.INFO)
end

---@param msg string
function M.error(msg)
  M.notify(msg, vim.log.levels.ERROR)
end

---@param msg string
function M.warn(msg)
  M.notify(msg, vim.log.levels.WARN)
end

---@generic T
---@param fn T
---@param ms? number
---@return T
function M.debounce(fn, ms)
  local timer = assert(vim.uv.new_timer())
  return function()
    timer:start(ms or 20, 0, vim.schedule_wrap(fn))
  end
end

---@param str string
function M.width(str)
  str = str:gsub("\t", string.rep(" ", vim.o.tabstop))
  return vim.api.nvim_strwidth(str)
end

--- UTF-8 aware word splitting. See |keyword|
---@param str string
function M.split_words(str)
  if str == "" then
    return {}
  end

  local ret = {} ---@type string[]
  local word = {} ---@type string[]
  local starts = vim.str_utf_pos(str)

  local function flush()
    if #word > 0 then
      ret[#ret + 1] = table.concat(word)
      word = {}
    end
  end

  for idx, start in ipairs(starts) do
    local stop = (starts[idx + 1] or (#str + 1)) - 1
    local ch = str:sub(start, stop)
    if vim.fn.charclass(ch) == 2 then -- iskeyword
      word[#word + 1] = ch
    else
      flush()
      ret[#ret + 1] = ch
    end
  end

  flush()
  return ret
end

--- UTF-8 aware character splitting
---@param str string
function M.split_chars(str)
  if str == "" then
    return {}
  end

  local ret = {} ---@type string[]
  local starts = vim.str_utf_pos(str)
  for i = 1, #starts - 1 do
    table.insert(ret, str:sub(starts[i], starts[i + 1] - 1))
  end
  table.insert(ret, str:sub(starts[#starts], #str))
  return ret
end

return M
