---@module 'luassert'

local Health = require("sidekick.health")

describe("health", function()
  local start_messages
  local reports
  local original_health
  local original_upvalues
  local orig_has
  local orig_is_enabled
  local orig_get_clients

  before_each(function()
    start_messages = {}
    reports = { ok = {}, warn = {}, error = {} }

    original_health = {
      start = vim.health.start,
      ok = vim.health.ok,
      warn = vim.health.warn,
      error = vim.health.error,
    }

    original_upvalues = {}
    for i = 1, 4 do
      local name, value = debug.getupvalue(Health.check, i)
      if name then
        original_upvalues[i] = value
      end
    end

    orig_has = vim.fn.has
    orig_is_enabled = vim.lsp.is_enabled
    orig_get_clients = vim.lsp.get_clients

    local function start_stub(msg)
      table.insert(start_messages, msg)
    end
    local function ok_stub(msg)
      table.insert(reports.ok, msg)
    end
    local function warn_stub(msg)
      table.insert(reports.warn, msg)
    end
    local function error_stub(msg)
      table.insert(reports.error, msg)
    end

    debug.setupvalue(Health.check, 1, start_stub)
    debug.setupvalue(Health.check, 2, ok_stub)
    debug.setupvalue(Health.check, 3, error_stub)
    debug.setupvalue(Health.check, 4, warn_stub)

  end)

  after_each(function()
    vim.health.start = original_health.start
    vim.health.ok = original_health.ok
    vim.health.warn = original_health.warn
    vim.health.error = original_health.error
    vim.fn.has = orig_has
    vim.lsp.is_enabled = orig_is_enabled
    vim.lsp.get_clients = orig_get_clients
    for i = 1, 4 do
      if original_upvalues[i] then
        debug.setupvalue(Health.check, i, original_upvalues[i])
      end
    end
  end)

  it("fails on old neovim", function()
    vim.fn.has = function()
      return 0
    end
    vim.lsp.is_enabled = function()
      return true
    end
    Health.check()
    assert.are.same({ "Sidekick" }, start_messages)
    assert.are.same({ "Neovim >= 0.11.2 is required" }, reports.error)
  end)

  it("reports copilot disabled", function()
    vim.fn.has = function()
      return 1
    end
    vim.lsp.get_clients = function()
      return {}
    end
    vim.lsp.is_enabled = function()
      return false
    end
    Health.check()
    assert.are.same({ "Copilot LSP is not enabled" }, reports.error)
  end)

  it("warns when handler not attached", function()
    vim.fn.has = function()
      return 1
    end
    vim.lsp.is_enabled = function()
      return true
    end
    vim.lsp.get_clients = function()
      return { { id = 1, handlers = {} } }
    end
    Health.check()
    assert.is_truthy(vim.tbl_filter(function(msg)
      return msg:find("not handling")
    end, reports.warn))
  end)
end)
