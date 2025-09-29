local Util = require("sidekick.util")

local M = {}

local patch_file = vim.fn.stdpath("state") .. "/sidekick-patch.json"
local patched = false

M.patches = {} ---@type table<string, sidekick.NesEdit>

function M.setup()
  local commands = {
    NesAdd = M.nes_add,
    NesPatch = M.nes_patch,
    NesEdit = function()
      vim.cmd.edit(patch_file)
    end,
  }
  for name, command in pairs(commands) do
    vim.api.nvim_create_user_command("SidekickDebug" .. name, command, {})
  end
  Util.warn("Sidekick debug enabled")
end

function M.nes_save()
  Util.info("Sidekick nes patches saved")
  vim.fn.writefile(vim.split(vim.json.encode(M.patches), "\n", { plain = true }), patch_file)
end

function M.nes_load()
  local ok, data = pcall(vim.fn.readfile, patch_file)
  if ok then
    Util.info("Sidekick nes patches loaded")
    M.patches = vim.json.decode(table.concat(data, "\n"))
  end
end

function M.nes_add()
  M.nes_load()
  local edit = require("sidekick.nes")._edits[1]
  if edit then
    edit.diff = nil
    edit.command = nil
    M.patches[vim.api.nvim_buf_get_name(0)] = edit
    M.nes_save()
    Util.info("Sidekick nes patch added")
  else
    Util.error("No edit found?")
  end
end

function M.nes_patch()
  if patched then
    return Util.error("NES already patched")
  end
  patched = true
  M.nes_load()
  local nes = require("sidekick.nes")
  local handler = nes._handler
  ---@diagnostic disable-next-line: duplicate-set-field
  nes._handler = function(err, res, ctx)
    local buf = ctx.bufnr or 0
    local name = vim.api.nvim_buf_get_name(buf)
    local edit = M.patches[name]
    if edit then
      vim.schedule(function()
        Util.warn("Patched `" .. name .. "`")
      end)
      edit.buf = buf
      edit.textDocument = vim.lsp.util.make_text_document_params(buf)
      edit.textDocument.version = vim.lsp.util.buf_versions[buf]
      res = vim.deepcopy({ edits = { edit } })
    end
    return handler(err, res, ctx)
  end
  require("sidekick.nes").update()
  Util.warn("Sidekick nes patched!")
end

return M
