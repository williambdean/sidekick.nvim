local Config = require("sidekick.config")
local TS = require("sidekick.treesitter")

local M = {}

---@alias sidekick.DiffText {text: string, lines: string[], virt_lines: sidekick.TSVirtualLines}

---@class sidekick.Diff
---@field range {from: sidekick.Pos, to: sidekick.Pos}
---@field hunks sidekick.diff.Hunk[]
---@field from sidekick.DiffText
---@field to sidekick.DiffText

---@class sidekick.Extmark: vim.api.keyset.set_extmark
---@field row integer
---@field col integer

---@class sidekick.diff.Hunk
---@field pos sidekick.Pos
---@field kind "add" | "delete" | "change"
---@field inline? boolean
---@field extmarks sidekick.Extmark[]

--- Calculate the result covering full lines
---@param edit sidekick.NesEdit
function M.parse_edit(edit)
  local lines = vim.api.nvim_buf_get_lines(edit.buf, edit.from[1], edit.to[1] + 1, false)
  local first, last = lines[1], lines[#lines]
  return table.concat(lines, "\n"), first:sub(1, edit.from[2]) .. edit.text .. last:sub(edit.to[2] + 1)
end

---@param a string[]
---@param b string[]
function M._diff(a, b)
  local txt_a = table.concat(a, "\n")
  local txt_b = table.concat(b, "\n")

  local diff_opts = vim.deepcopy(Config.nes.diff)
  diff_opts.inline = nil
  diff_opts.result_type = "indices"
  return vim.text.diff(txt_a, txt_b, diff_opts) --[[@as (integer[][])]]
end

---@param edit sidekick.NesEdit
function M.diff(edit)
  if edit.diff then
    return edit.diff
  end

  local from_text, to_text = M.parse_edit(edit)
  local to_lines = vim.split(to_text, "\n", { plain = true })
  local from_lines = vim.split(from_text, "\n", { plain = true })

  ---@type sidekick.Diff
  local ret = {
    hunks = {},
    range = { from = edit.from, to = edit.to },
    from = {
      text = from_text,
      lines = from_lines,
      virt_lines = TS.get_virtual_lines(from_lines, {
        ft = vim.bo[edit.buf].filetype,
      }),
    },
    to = {
      text = to_text,
      lines = to_lines,
      virt_lines = TS.get_virtual_lines(to_lines, {
        ft = vim.bo[edit.buf].filetype,
        bg = "SidekickDiffAdd",
        -- ws = "SidekickDiffContext",
      }),
    },
  }

  M.diff_lines(ret)

  edit.diff = ret
  return ret
end

---@param diff sidekick.Diff
function M.diff_lines(diff)
  local hunks = M._diff(diff.from.lines, diff.to.lines)
  for _, hunk in ipairs(hunks) do
    local ai, ac, bi, bc = unpack(hunk)

    local token_hunks = ac >= 1 and bc >= 1 and M.diff_tokens(diff, hunk)
    if token_hunks then
      vim.list_extend(diff.hunks, token_hunks)
    else
      local row = diff.range.from[1] + ai - 1
      ---@type sidekick.diff.Hunk
      local h = {
        kind = ac > 0 and bc > 0 and "change" or ac > 0 and "delete" or "add",
        pos = { row, 0 },
        extmarks = {},
      }
      table.insert(diff.hunks, h)
      if ac > 0 then
        table.insert(h.extmarks, {
          row = row,
          col = 0,
          end_line = row + ac - 1,
          end_col = #diff.from.lines[ai + ac - 1],
          hl_group = "SidekickDiffDelete",
        })
      end
      if bc > 0 then
        table.insert(h.extmarks, {
          row = row + (ac > 0 and ac - 1 or 0),
          col = 0,
          hl_eol = true,
          virt_lines = vim.list_slice(diff.to.virt_lines, bi, bi + bc - 1),
        })
      end
    end
  end
end

---@param str string
---@return string[]
function M.tokenize(str)
  local parts, i, len = {}, 1, #str
  while i <= len do
    local from, to = str:find("^[%w_]+", i)
    if from then
      table.insert(parts, str:sub(i, to))
      i = to + 1
    else
      table.insert(parts, str:sub(i, i))
      i = i + 1
    end
  end
  assert(str == table.concat(parts, ""), "tokenize mismatch")
  return parts
end

---@param diff sidekick.Diff
---@param line_idx integer
---@param line_count integer
---@param vl_all sidekick.TSVirtualLines
function M._index(diff, line_idx, line_count, vl_all)
  local toks = {} ---@type string[]
  local vl = {} ---@type sidekick.TSVirtualText
  local index = {} ---@type table<integer, {row: integer, col: integer, end_col: integer}>
  index[0] = { row = diff.range.from[1] + line_idx - 1, col = 0, end_col = 0 }
  for l = line_idx, line_idx + line_count - 1 do
    local col = 0
    for _, t in ipairs(vl_all[l] or {}) do
      local parts = M.tokenize(t[1])
      -- parts = { t[1] } -- FIXME: disable tokenization for now
      -- parts = vim.split(t[1], "", { plain = true }) -- FIXME: char by char for now
      for _, p in ipairs(parts) do
        local idx = #toks + 1
        toks[idx] = p
        vl[idx] = { p, t[2] }
        index[idx] = {
          row = diff.range.from[1] + l - 1,
          col = col,
          end_col = col + #p,
        }
        col = col + #p
      end
    end
  end
  return toks, index, vl
end

---@param diff sidekick.Diff
---@param offset integer[]
function M.diff_tokens(diff, offset)
  local a_toks, a_index = M._index(diff, offset[1], offset[2], diff.from.virt_lines)
  local b_toks, b_index, b_vl = M._index(diff, offset[3], offset[4], diff.to.virt_lines)

  local hunks = M._diff(a_toks, b_toks)
  local ret = {} ---@type sidekick.diff.Hunk[]

  for _, hunk in ipairs(hunks) do
    local ai, ac, bi, bc = unpack(hunk)
    local row = a_index[ai].row
    ---@type sidekick.diff.Hunk
    local h = {
      kind = ac > 0 and bc > 0 and "change" or ac > 0 and "delete" or "add",
      pos = { row, a_index[ai].col },
      inline = true,
      extmarks = {},
    }
    if ac > 0 then
      if a_index[ai + ac - 1].row > a_index[ai].row then
        return -- multiline hunk
      end
      table.insert(h.extmarks, {
        row = row,
        col = a_index[ai].col,
        end_col = a_index[ai + ac - 1].end_col,
        hl_group = "SidekickDiffDelete",
      })
    end
    if bc > 0 then
      if b_index[bi + bc - 1].row > b_index[bi].row then
        return -- multiline hunk
      end
      local col = a_index[ai].col
      if ac == 0 then
        col = a_index[ai].end_col
        h.pos[2] = math.max(col - 1, 0)
      else
        col = a_index[ai + ac - 1].end_col
      end
      table.insert(h.extmarks, {
        row = row,
        col = col,
        virt_text_pos = "inline",
        priority = 500,
        virt_text = vim.list_slice(b_vl, bi, bi + bc - 1),
      })
    end
    table.insert(ret, h)
  end
  return ret
end

return M
