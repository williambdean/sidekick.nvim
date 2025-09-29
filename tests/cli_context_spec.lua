---@module 'luassert'

local Context = require("sidekick.cli.context")

describe("cli context", function()
  local original_buf
  local buf
  local orig_diag_get

  local function set_named_buffer(name, lines)
    buf = vim.api.nvim_create_buf(false, true)
    if name then
      local path = name
      if not name:match("^/") then
        path = vim.fs.joinpath(vim.uv.cwd(), name)
      end
      vim.api.nvim_buf_set_name(buf, path)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "one", "two", "three" })
    vim.api.nvim_set_current_buf(buf)
    return buf
  end

  before_each(function()
    original_buf = vim.api.nvim_get_current_buf()
    orig_diag_get = vim.diagnostic.get
  end)

  after_each(function()
    vim.api.nvim_set_current_buf(original_buf)
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    buf = nil
    vim.diagnostic.get = orig_diag_get
  end)

  it("formats current cursor location", function()
    set_named_buffer("tmp.lua", { "local a", "local b" })
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    local loc = Context.get_location(buf)
    assert.are.same("@tmp.lua:2:3", loc)
  end)

  it("formats explicit ranges and sorts endpoints", function()
    local loc = Context.format_location({
      name = "foo.lua",
      range = {
        from = { 3, 5 },
        to = { 2, 4 },
        kind = "char",
      },
    })
    assert.are.same("@foo.lua:2:5-3:6", loc)
  end)

  it("falls back to placeholder for unnamed buffers", function()
    set_named_buffer(nil, { "line" })
    local loc = Context.get_location(buf)
    assert.are.same("@[No Name]:1:1", loc)
  end)

  it("includes diagnostics without end positions", function()
    set_named_buffer("diag.lua", { "return oops" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    vim.diagnostic.get = function(target)
      if target == buf then
        return {
          {
            bufnr = buf, -- changed to use the 'bufnr' from the outer scope
            lnum = 0,
            col = 2,
            severity = vim.diagnostic.severity.ERROR,
            message = "needs fixing\nnow",
          },
        }
      end
      return {}
    end

    local text = Context.get_diagnostics(buf)
    assert.is_truthy(text)
    assert.are.same("[ERROR] needs fixing now @diag.lua:1:3-3", text)
  end)
end)
