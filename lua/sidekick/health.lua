local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error

function M.check()
  start("Sidekick")

  if vim.fn.has("nvim-0.11.2") == 1 then
    ok("Using Neovim >= 0.11.2")
  else
    error("Neovim >= 0.11.2 is required")
    return
  end

  if vim.lsp.is_enabled("copilot") then
    ok("Copilot LSP is enabled")
  else
    error("Copilot LSP is not enabled")
  end

  for _, client in ipairs(vim.lsp.get_clients({ name = "copilot" })) do
    if client.handlers["didChangeStatus"] == require("sidekick.status").on_status then
      ok("Sidekick is handling Copilot LSP status notifications for client: " .. client.id)
    else
      warn("Sidekick is not handling Copilot LSP status notifications for client: " .. client.id)
    end
  end
end

return M
