---@module 'luassert'

local Context = require("sidekick.cli.context")

describe("cli context", function()
  local original_buf
  local buf
  local orig_diag_get
  local orig_getbufinfo
  local extra_bufs

  local function track_buffer(target)
    extra_bufs[#extra_bufs + 1] = target
    return target
  end

  local function set_named_buffer(name, lines)
    buf = track_buffer(vim.api.nvim_create_buf(false, true))
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
    orig_getbufinfo = vim.fn.getbufinfo
    extra_bufs = {}
  end)

  after_each(function()
    vim.api.nvim_set_current_buf(original_buf)
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    for _, b in ipairs(extra_bufs) do
      if vim.api.nvim_buf_is_valid(b) then
        vim.api.nvim_buf_delete(b, { force = true })
      end
    end
    buf = nil
    extra_bufs = nil
    vim.diagnostic.get = orig_diag_get
    vim.fn.getbufinfo = orig_getbufinfo
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

  it("prefers most recent non-cli buffer when invoked from a cli buffer", function()
    local cli = set_named_buffer("cli", { "prompt" })
    vim.b[cli].sidekick_cli = true

    local stale = track_buffer(vim.api.nvim_create_buf(true, false))
    vim.api.nvim_buf_set_name(stale, vim.fs.joinpath(vim.uv.cwd(), "stale.lua"))

    local recent = track_buffer(vim.api.nvim_create_buf(true, false))
    vim.api.nvim_buf_set_name(recent, vim.fs.joinpath(vim.uv.cwd(), "recent.lua"))

    vim.fn.getbufinfo = function()
      return {
        { bufnr = stale, hidden = 0, lastused = 100 },
        { bufnr = recent, hidden = 0, lastused = 200 },
      }
    end

    local context = Context.get({ location = { row = false, col = false, range = false } })

    assert.are.same({ "@recent.lua" }, context)
  end)
end)
