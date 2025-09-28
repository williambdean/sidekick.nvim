local Config = require("sidekick.config")
local Terminal = require("sidekick.cli.terminal")
local Util = require("sidekick.util")

local M = {}

---@class sidekick.Prompt
---@field msg? string
---@field location? boolean include the buffer location (defaults to true)
---@field diagnostics? boolean include the buffer diagnostics (defaults to false)

---@alias sidekick.Prompt.spec sidekick.Prompt | string | fun(): (sidekick.Prompt|string)

---@class sidekick.cli.Tool.spec
---@field cmd string[] Command to run the CLI tool
---@field env? table<string, string> Environment variables to set when running the command

---@class sidekick.cli.Tool: sidekick.cli.Tool.spec
---@field name string
---@field installed boolean
---@field running boolean

---@class sidekick.cli.Filter
---@field name? string
---@field installed? boolean
---@field running? boolean

---@class sidekick.cli.With
---@field filter? sidekick.cli.Filter
---@field create? boolean
---@field all? boolean

---@class sidekick.cli.Show
---@field name? string
---@field focus? boolean
---@field on_show? fun(terminal: sidekick.cli.Terminal)

---@class sidekick.cli.Hide
---@field name? string
---@field all? boolean

---@class sidekick.cli.Select: sidekick.cli.With
---@field on_select? fun(t:sidekick.cli.Tool)

---@class sidekick.cli.Ask: sidekick.cli.Show,sidekick.Prompt
---@field prompt? string
---@field submit? boolean

---@class sidekick.cli.Keymap: vim.keymap.set.Opts
---@field mode? string|string[]

---@param opts? sidekick.cli.Select
function M.select_tool(opts)
  opts = opts or {}
  local tools = M.get_tools(opts.filter)

  local on_select = function(choice)
    if choice then
      if opts.on_select then
        return opts.on_select(choice)
      end
      M.show({ name = choice.name, focus = opts.focus })
    end
  end

  if #tools == 0 then
    Util.warn("No tools to select")
    return
  elseif #tools == 1 then
    on_select(tools[1])
    return
  end

  vim.ui.select(tools, {
    prompt = "Select CLI tool:",
    ---@param tool sidekick.cli.Tool
    format_item = function(tool)
      local parts = { tool.name }
      if not tool.installed then
        parts[#parts + 1] = "[not installed]"
      elseif tool.running then
        parts[#parts + 1] = "[running]"
      end
      return table.concat(parts, " ")
    end,
  }, on_select)
end

---@param t sidekick.cli.Terminal|sidekick.cli.Tool
---@param filter? sidekick.cli.Filter
function M.is(t, filter)
  filter = filter or {}
  t = getmetatable(t) == Terminal and t.tool or t
  ---@cast t sidekick.cli.Tool
  local terminal = Terminal.get(t.name)
  return (filter.name == nil or filter.name == t.name)
    and (filter.installed == nil or filter.installed == t.installed)
    and (filter.running == nil or filter.running == (terminal and terminal:is_running()))
end

---@param filter? sidekick.cli.Filter
---@return sidekick.cli.Tool[]
function M.get_tools(filter)
  local all = {} ---@type sidekick.cli.Tool[]
  for name, tool in pairs(Config.cli.tools) do
    ---@cast tool sidekick.cli.Tool
    tool.name = name
    tool.installed = vim.fn.executable(tool.cmd[1]) == 1
    local terminal = Terminal.get(name)
    tool.running = terminal and terminal:is_running()
    all[#all + 1] = tool
  end
  ---@type sidekick.cli.Tool[]
  ---@param t sidekick.cli.Tool
  local ret = vim.tbl_filter(function(t)
    return M.is(t, filter)
  end, all)
  table.sort(ret, function(a, b)
    if a.installed ~= b.installed then
      return a.installed
    end
    if a.running ~= b.running then
      return a.running
    end
    return a.name < b.name
  end)
  return ret
end

---@param filter? sidekick.cli.Filter
function M.get_terminals(filter)
  ---@param t sidekick.cli.Terminal
  local ret = vim.tbl_filter(function(t)
    return M.is(t, filter)
  end, Terminal.terminals) --[[@as sidekick.cli.Terminal[] ]]
  table.sort(ret, function(a, b)
    return a.atime > b.atime
  end)
  return ret
end

---@param cb fun(terminal: sidekick.cli.Terminal)
---@param opts? sidekick.cli.With
function M.with(cb, opts)
  opts = opts or {}
  cb = vim.schedule_wrap(cb)
  local terminals = M.get_terminals(opts.filter)
  terminals = opts.all and terminals or { terminals[1] }
  if #terminals == 0 and opts.create then
    M.select_tool({
      filter = opts.filter,
      on_select = function(tool)
        if vim.fn.executable(tool.cmd[1]) == 0 then
          Util.error(("`%s` is not installed"):format(tool.cmd[1]))
          return
        end
        cb(Terminal.new(tool))
      end,
    })
  else
    vim.tbl_map(cb, terminals)
  end
end

---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.show(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    t:show()
    if t:is_open() then
      if opts.focus ~= false then
        t:focus()
      end
      if opts.on_show then
        vim.schedule(function()
          opts.on_show(t)
        end)
      end
    end
  end, { filter = { name = opts.name }, create = true })
end

---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.toggle(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    t:toggle()
    if t:is_open() and opts.focus ~= false then
      t:focus()
    end
  end, { filter = { name = opts.name }, create = true })
end

---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
function M.hide(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    t:hide()
  end, { filter = { name = opts.name, running = true }, all = opts.all })
end

---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
function M.close(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    t:close()
  end, { filter = { name = opts.name, running = true }, all = opts.all })
end

---@param opts? sidekick.cli.Ask
function M.render_prompt(opts)
  opts = opts or {}
  opts = type(opts) == "string" and { msg = opts } or opts

  if opts.prompt then
    ---@type sidekick.Prompt.spec
    local prompt = Config.cli.prompts[opts.prompt]
    if not prompt then
      Util.error("Prompt `" .. opts.prompt .. "` does not exist")
      return
    end
    prompt = type(prompt) == "function" and prompt() or prompt
    if type(prompt) == "string" then
      opts.msg = prompt .. (opts.msg and "\n" .. opts.msg or "")
    elseif type(prompt) == "table" then
      opts = vim.tbl_deep_extend("force", opts, prompt)
    end
  end

  local msg = {} ---@type string[]

  local Context = require("sidekick.cli.context")

  if opts.location ~= false then
    msg[#msg + 1] = Context.get_location()
  end

  if opts.diagnostics then
    msg[#msg + 1] = Context.get_diagnostics()
  end

  msg[#msg + 1] = opts.msg or ""

  return table.concat(msg, "\n")
end

---@param opts? sidekick.cli.Ask
---@overload fun(msg:string)
function M.ask(opts)
  opts = opts or {}

  local prompt = M.render_prompt(opts)
  if not prompt then
    return
  end

  opts.on_show = function(terminal)
    terminal:send(prompt)
    if opts.submit then
      terminal:submit()
    end
  end

  M.show(opts)
end

function M.select_prompt()
  local ok = pcall(require, "snacks.picker")
  if ok then
    local snacks = require("snacks")
    snacks.picker.sources.sidekick_prompts = require("sidekick.cli.snacks").prompts
    snacks.picker.sidekick_prompts()
    return
  end
  local prompts = vim.tbl_keys(Config.cli.prompts)
  vim.ui.select(prompts, {
    prompt = "Select a prompt",
    format_item = function(prompt)
      return ("[%s] %s"):format(prompt, M.render_prompt({ prompt = prompt }))
    end,
  }, function(choice)
    if choice then
      M.ask({ prompt = choice })
    end
  end)
  -- Snacks.picker.
end

return M
