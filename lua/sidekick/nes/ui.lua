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
  vim.b[edit.buf].sidekick_nes = true
  local diff = require("sidekick.nes.diff").diff(edit)

  local from, to = edit.from, edit.to

  vim.api.nvim_buf_set_extmark(edit.buf, Config.ns, from[1], 0, {
    end_line = to[1] + 1,
    hl_group = "SidekickDiffContext",
    hl_eol = true,
  })

  local signs = Config.signs.enabled

  for _, hunk in ipairs(diff.hunks) do
    if signs then
      vim.api.nvim_buf_set_extmark(edit.buf, Config.ns, hunk.pos[1], 0, {
        sign_text = Config.signs.change,
        sign_hl_group = "SidekickSign" .. hunk.kind:sub(1, 1):upper() .. hunk.kind:sub(2),
      })
    end

    for _, extmark in ipairs(hunk.extmarks) do
      local opts = vim.tbl_extend("force", {}, extmark) ---@type sidekick.Extmark
      opts.row, opts.col = nil, nil
      vim.api.nvim_buf_set_extmark(edit.buf, Config.ns, extmark.row, extmark.col, opts)
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
