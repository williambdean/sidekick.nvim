---@class sidekick.config: sidekick.Config
local M = {}

M.ns = vim.api.nvim_create_namespace("sidekick.ui")

---@class sidekick.Config
local defaults = {
  jump = {
    jumplist = true, -- add an entry to the jumplist
  },
  signs = {
    enabled = true, -- enable signs by default
    add = " ",
    change = " ",
    delete = " ",
  },
  nes = {
    debounce = 100,
    trigger = {
      -- events that trigger sidekick next edit suggestions
      events = { "InsertLeave", "TextChanged", "User SidekickNesDone" },
    },
    clear = {
      -- events that clear the current next edit suggestion
      events = { "TextChangedI", "BufWritePre", "InsertEnter" },
      esc = true, -- clear next edit suggestions when pressing <Esc>
    },
    ---@class sidekick.diff.Opts: vim.text.diff.Opts
    ---@field inline? boolean Enable inline diffs
    diff = {
      inline = true,
      algorithm = "patience",
      linematch = true,
    },
  },
}

local config = vim.deepcopy(defaults) --[[@as sidekick.Config]]

---@param opts? sidekick.Config
function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  local group = vim.api.nvim_create_augroup("sidekick", { clear = true })

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
        return require("sidekick.status")._handler(...)
      end,
    },
  })

  vim.schedule(function()
    M.set_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = M.set_hl,
    })

    ---@param events string[]
    ---@param fn fun()
    local function on(events, fn)
      for _, event in ipairs(events) do
        local name, pattern = event:match("^(%S+)%s*(.*)$") --[[@as string, string]]
        vim.api.nvim_create_autocmd(name, {
          pattern = pattern ~= "" and pattern or nil,
          group = group,
          callback = fn,
        })
      end
    end

    on(M.nes.clear.events, require("sidekick").clear)
    on(M.nes.trigger.events, require("sidekick.util").debounce(require("sidekick.nes").update, M.nes.debounce))

    if M.nes.clear.esc then
      local ESC = vim.keycode("<Esc>")
      vim.on_key(function(_, typed)
        if typed == ESC then
          require("sidekick").clear()
        end
      end, nil)
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
    vim.api.nvim_set_hl(0, "Sidekick" .. from, { link = to, default = true })
  end
end

setmetatable(M, {
  __index = function(_, key)
    return config[key]
  end,
})

return M
