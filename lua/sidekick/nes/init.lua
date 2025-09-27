local Config = require("sidekick.config")

local M = {}

---@alias sidekick.Pos {[1]:integer, [2]:integer}

---@class sidekick.lsp.NesEdit
---@field command lsp.Command
---@field range lsp.Range
---@field text string
---@field textDocument {uri: string, version: integer}

---@class sidekick.NesEdit: sidekick.lsp.NesEdit
---@field buf integer
---@field from sidekick.Pos
---@field to sidekick.Pos
---@field diff? sidekick.Diff

M._edits = {} ---@type sidekick.NesEdit[]
M._requests = {} ---@type table<number, number>

function M.update()
  M.cancel()
  local buf = vim.api.nvim_get_current_buf()
  local client = Config.get_client(buf)
  if not client then
    return
  end

  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  ---@diagnostic disable-next-line: inject-field
  params.textDocument.version = vim.lsp.util.buf_versions[buf]

  ---@diagnostic disable-next-line: param-type-mismatch
  local ok, request_id = client:request("textDocument/copilotInlineEdit", params, M._handler)
  if ok and request_id then
    M._requests[client.id] = request_id
  end
end

---@param buf? number
function M.get(buf)
  ---@param edit sidekick.NesEdit
  return vim.tbl_filter(function(edit)
    if not vim.api.nvim_buf_is_valid(edit.buf) then
      return false
    end
    if edit.textDocument.version ~= vim.lsp.util.buf_versions[edit.buf] then
      return false
    end
    return buf == nil or edit.buf == buf
  end, M._edits)
end

function M.clear()
  M.cancel()
  M._edits = {}
  require("sidekick.nes.ui").hide()
end

--- Cancel pending requests
function M.cancel()
  for client_id, request_id in pairs(M._requests) do
    M._requests[client_id] = nil
    local client = vim.lsp.get_client_by_id(client_id)
    if client then
      client:cancel_request(request_id)
    end
  end
end

---@param res {edits: sidekick.lsp.NesEdit[]}
---@type lsp.Handler
function M._handler(err, res, ctx)
  M._requests[ctx.client_id] = nil

  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if err or not client then
    return
  end

  M._edits = {}

  res = res or { edits = {} }

  ---@param buf number
  ---@param p lsp.Position
  ---@return sidekick.Pos
  local function pos(buf, p)
    local line = vim.api.nvim_buf_get_lines(buf, p.line, p.line + 1, false)[1] or ""
    return { p.line, vim.str_byteindex(line, client.offset_encoding, p.character, false) }
  end

  for _, edit in ipairs(res.edits or {}) do
    local fname = vim.uri_to_fname(edit.textDocument.uri)
    local buf = vim.fn.bufnr(fname, false)
    if buf and vim.api.nvim_buf_is_valid(buf) then
      ---@cast edit sidekick.NesEdit
      edit.buf = buf
      edit.from, edit.to = pos(buf, edit.range.start), pos(buf, edit.range["end"])
      table.insert(M._edits, edit)
    end
  end

  require("sidekick.nes.ui").update()
end

---@return boolean true if jumped
function M.jump()
  local buf = vim.api.nvim_get_current_buf()
  local edit = M.get(buf)[1]

  if not edit then
    return false
  end

  local diff = require("sidekick.nes.diff").diff(edit)
  local hunk = vim.deepcopy(diff.hunks[1])
  local pos = hunk.pos

  return M._jump(pos)
end

---@param pos sidekick.Pos
function M._jump(pos)
  pos = vim.deepcopy(pos)

  -- check if we need to jump
  pos[1] = pos[1] + 1
  local cursor = vim.api.nvim_win_get_cursor(0)
  if cursor[1] == pos[1] and cursor[2] == pos[2] then
    return false
  end

  -- schedule jump
  vim.schedule(function()
    -- add to jump list
    if Config.jump.jumplist then
      vim.cmd("normal! m'")
    end
    vim.api.nvim_win_set_cursor(0, pos)
  end)

  return true
end

function M.have()
  return #M.get(vim.api.nvim_get_current_buf()) > 0
end

---@return boolean true if text edit was applied
function M.apply()
  local buf = vim.api.nvim_get_current_buf()
  local client = Config.get_client(buf)
  local edits = M.get(buf)
  if not client or #edits == 0 then
    return false
  end
  ---@param edit sidekick.NesEdit
  local text_edits = vim.tbl_map(function(edit)
    return {
      range = edit.range,
      newText = edit.text,
    }
  end, edits) --[[@as lsp.TextEdit[] ]]
  vim.schedule(function()
    local last = edits[#edits]
    local diff = require("sidekick.nes.diff").diff(last)

    vim.lsp.util.apply_text_edits(text_edits, buf, client.offset_encoding)
    for _, edit in ipairs(edits) do
      client:exec_cmd(edit.command, { bufnr = buf })
    end

    -- jump to end of last edit
    local pos = vim.deepcopy(last.from)
    if #diff.to.lines >= 1 then
      pos[1] = pos[1] + (#diff.to.lines - 1)
      pos[2] = pos[2] + #diff.to.text
    end
    M._jump(pos)

    vim.api.nvim_exec_autocmds("User", {
      pattern = "SidekickNesDone",
      data = { client_id = client.id, buffer = buf },
    })
  end)
  M.clear()
  return true
end

return M
