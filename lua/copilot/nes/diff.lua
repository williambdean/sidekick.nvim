local Config = require("copilot.config")

local M = {}

---@alias copilot.DiffText {text: string, lines: string[]}

---@class copilot.Diff
---@field hunks copilot.DiffHunk[]
---@field from copilot.DiffText
---@field to copilot.DiffText

--- (0,0)-indexed, end-exclusive
---@class copilot.DiffDelete
---@field from copilot.Pos
---@field to copilot.Pos

--- (0,0)-indexed, end-exclusive
---@class copilot.DiffAdd
---@field pos copilot.Pos (0-0)-indexed pos of the add
---@field from copilot.Pos (1,1)-indexed start in new text
---@field to copilot.Pos (1,1)-indexed start in new text

---@class copilot.DiffHunk
---@field kind "inline" | "block"
---@field pos copilot.Pos
---@field delete? copilot.DiffDelete
---@field add? copilot.DiffAdd

--- Calculate the result covering full lines
---@param edit copilot.NesEdit
function M.parse_edit(edit)
  local lines = vim.api.nvim_buf_get_lines(edit.buf, edit.from[1], edit.to[1] + 1, false)
  local first, last = lines[1], lines[#lines]
  return table.concat(lines, "\n"), first:sub(1, edit.from[2]) .. edit.text .. last:sub(edit.to[2] + 1)
end

---@param edit copilot.NesEdit
function M.diff(edit)
  if edit.diff then
    return edit.diff
  end
  local old_text, new_text = M.parse_edit(edit)
  local new_lines = vim.split(new_text, "\n", { plain = true })
  local old_lines = vim.split(old_text, "\n", { plain = true })

  ---@type copilot.Diff
  local ret = {
    hunks = {},
    from = { text = old_text, lines = old_lines },
    to = { text = new_text, lines = new_lines },
  }

  local diff_opts = vim.deepcopy(Config.nes.diff)
  diff_opts.inline = nil
  local hunks = vim.text.diff(old_text, new_text, diff_opts) --[[@as (integer[][])]]

  for _, hunk in ipairs(hunks) do
    vim.b[edit.buf].copilot_nes = true
    local ai, ac, bi, bc = unpack(hunk)
    if Config.nes.diff.inline and ac == 1 and bc == 1 then
      -- Inline Change
      local row = edit.from[1] + ai - 1

      local diff_from, a_to, b_to = M.line_diff(old_lines[ai], new_lines[bi])
      ---@type copilot.DiffHunk
      local h = {
        kind = "inline",
        pos = { row, diff_from - 1 },
      }
      table.insert(ret.hunks, h)
      if a_to >= diff_from then
        h.delete = {
          from = { row, diff_from - 1 },
          to = { row, a_to },
        }
      end
      if b_to >= diff_from then
        h.add = {
          pos = { row, a_to },
          from = { bi, diff_from },
          to = { bi, b_to },
        }
      end
    else
      -- Block Change
      local row = edit.from[1] + ai - 1
      ---@type copilot.DiffHunk
      local h = {
        kind = "block",
        pos = { row, 0 },
      }
      table.insert(ret.hunks, h)
      if ac > 0 then
        h.delete = {
          from = { row, 0 },
          to = { row + ac - 1, #old_lines[ai] },
        }
      end
      if bc > 0 then
        h.add = {
          pos = { row + ac, 0 },
          from = { bi, 0 },
          to = { bi + bc - 1, 0 },
        }
      end
    end
  end
  edit.diff = ret
  return ret
end

--- Calculate the diff between two lines
---@param a string
---@param b string
---@return number from, number to_a, number to_b (1-based, inclusive)
function M.line_diff(a, b)
  local from = 0
  for i = 1, math.min(#a, #b) do
    if a:sub(i, i) ~= b:sub(i, i) then
      break
    end
    from = i
  end

  local to_offset = 0
  for i = 1, math.min(#a, #b) - from do
    if a:sub(#a - i + 1, #a - i + 1) ~= b:sub(#b - i + 1, #b - i + 1) then
      break
    end
    to_offset = i
  end

  return from + 1, #a - to_offset, #b - to_offset
end

return M
