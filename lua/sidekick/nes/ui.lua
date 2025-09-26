local Config = require("sidekick.config")
local Nes = require("sidekick.nes")
local TS = require("sidekick.treesitter")

local M = {}

--- Calculate the result covering full lines
---@param edit sidekick.NesEdit
function M.parse_edit(edit)
  local lines = vim.api.nvim_buf_get_lines(edit.buf, edit.from[1], edit.to[1] + 1, false)
  local first, last = lines[1], lines[#lines]
  return table.concat(lines, "\n"), first:sub(1, edit.from[2]) .. edit.text .. last:sub(edit.to[2] + 1)
end

---@param edit sidekick.NesEdit
function M.render(edit)
  local diff = require("sidekick.nes.diff").diff(edit)

  local from, to = edit.from, edit.to

  local virt_lines = TS.get_virtual_lines(diff.to.lines, {
    ft = vim.bo[edit.buf].filetype,
    bg = "SidekickDiffAdd",
    ws = "SidekickDiffContext",
  })

  vim.api.nvim_buf_set_extmark(edit.buf, Config.ns, from[1], 0, {
    end_line = to[1] + 1,
    hl_group = "SidekickDiffContext",
    hl_eol = true,
  })

  local signs = Config.signs.enabled

  for _, hunk in ipairs(diff.hunks) do
    vim.b[edit.buf].sidekick_nes = true
    if hunk.kind == "inline" then
      -- Inline Change
      local row = hunk.pos[1]
      if signs then
        vim.api.nvim_buf_set_extmark(edit.buf, Config.ns, row, 0, {
          sign_text = Config.signs.change,
          sign_hl_group = "SidekickSignChange",
        })
      end
      if hunk.delete then
        vim.api.nvim_buf_set_extmark(edit.buf, Config.ns, hunk.delete.from[1], hunk.delete.from[2], {
          end_col = hunk.delete.to[2],
          hl_group = "SidekickDiffDelete",
        })
      end
      if hunk.add then
        local add = TS.slice(virt_lines[hunk.add.from[1]], hunk.add.from[2], hunk.add.to[2])
        vim.api.nvim_buf_set_extmark(edit.buf, Config.ns, hunk.add.pos[1], hunk.add.pos[2], {
          virt_text_pos = "inline",
          virt_text = add,
        })
      end
    else
      -- Block Change
      if hunk.delete then
        vim.api.nvim_buf_set_extmark(edit.buf, Config.ns, hunk.delete.from[1], hunk.delete.from[2], {
          end_line = hunk.delete.to[1],
          end_col = hunk.delete.to[2],
          hl_group = "SidekickDiffDelete",
          sign_text = signs and Config.signs.delete or nil,
          sign_hl_group = signs and "SidekickSignDelete" or nil,
        })
      end
      if hunk.add then
        local add = vim.list_slice(virt_lines, hunk.add.from[1], hunk.add.to[1])
        vim.api.nvim_buf_set_extmark(edit.buf, Config.ns, hunk.add.pos[1], hunk.add.pos[2], {
          hl_eol = true,
          virt_lines = vim.tbl_map(function(vt)
            -- HACK: make sure the virtual line covers the full width
            table.insert(vt, { string.rep(" ", vim.o.columns), "SidekickDiffContext" })
            return vt
          end, add),
          hl_mode = "combine",
          -- the below doesn't work well with virt_lines, so disable for now
          -- sign_text = Config.signs.add,
          -- sign_hl_group = "SidekickSignAdd",
        })
      end
    end
  end
end

---@param buf number
function M._hide(buf)
  if vim.b[buf].sidekick_nes then
    vim.api.nvim_buf_clear_namespace(buf, Config.ns, 0, -1)
  end
end

function M.update()
  local edits = Nes.get()
  M.hide()
  vim.tbl_map(M.render, edits)
end

function M.hide()
  vim.tbl_map(M._hide, vim.api.nvim_list_bufs())
end

return M
