---@class copilot.config: copilot.Config
local M = {}

M.ns = vim.api.nvim_create_namespace("copilot.ui")

---@class copilot.Config
local defaults = {
  jump = {
    jumplist = true, -- add an entry to the jumplist
  },
  signs = {
    add = " ",
    change = " ",
    delete = " ",
  },
  nes = {
    debounce = 100,
    -- Events that trigger copilot next edit suggestions
    -- Set to the empty list if you want to manually trigger next edits
    -- Only trigger NES updates:
    -- * when leaving insert mode
    -- * when text is changed (in normal mode)
    -- * when accepting a next edit suggestion
    events = { "InsertLeave", "TextChanged", "User CopilotNesDone" },
  },
}

---@type copilot.Config
local config = vim.deepcopy(defaults)

---@param opts? copilot.Config
function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  local group = vim.api.nvim_create_augroup("copilot", { clear = true })

  -- Copilot requires the custom didFocus notification
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      local client = M.get_client(ev.buf)
      if not client then
        return
      end

      ---@diagnostic disable-next-line: param-type-mismatch
      client:notify("textDocument/didFocus", {
        textDocument = { uri = vim.uri_from_bufnr(ev.buf) },
      })
    end,
  })

  vim.lsp.config("copilot", {
    handlers = {
      didChangeStatus = function(...)
        return require("copilot.status")._handler(...)
      end,
    },
  })

  vim.schedule(function()
    M.set_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = M.set_hl,
    })

    local update = require("copilot.util").debounce(require("copilot.nes").update, M.nes.debounce)
    for _, event in ipairs(config.nes.events) do
      local name, pattern = event:match("^(%S+)%s*(.*)$") --[[@as string, string]]
      vim.api.nvim_create_autocmd(name, {
        pattern = pattern ~= "" and pattern or nil,
        group = group,
        callback = update,
      })
    end
  end)
end

---@param buf? number
function M.get_client(buf)
  return vim.lsp.get_clients({ name = "copilot", bufnr = buf or 0 })[1]
end

function M.set_hl()
  local links = {
    DiffContext = "DiffChange",
    DiffAdd = "DiffText",
    DiffDelete = "DiffDelete",
    SignAdd = "DiagnosticSignOk",
    SignChange = "DiagnosticSignWarn",
    SignDelete = "DiagnosticSignError",
  }
  for from, to in pairs(links) do
    vim.api.nvim_set_hl(0, "Copilot" .. from, { link = to, default = true })
  end
end

setmetatable(M, {
  __index = function(_, key)
    return config[key]
  end,
})

return M
