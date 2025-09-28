---@diagnostic disable: inject-field

local Cli = require("sidekick.cli")
local Config = require("sidekick.config")

---@module 'snacks'

local M = {}

---@type snacks.picker.Config
M.prompts = {
  name = "Sidekick Prompt",
  ---@type snacks.picker.finder
  finder = function(opts, ctx)
    local ret = {} ---@type snacks.picker.finder.Item[]
    for name in pairs(Config.cli.prompts) do
      ret[#ret + 1] = {
        text = name,
        value = name,
        preview = { text = Cli.render_prompt({ prompt = name }) },
      }
    end
    return ret
  end,
  ---@param item snacks.picker.Item
  ---@param picker snacks.Picker
  format = function(item, picker)
    return { { item.text, "Special" } }
  end,
  preview = "preview",
  layout = { preset = "dropdown" },
  confirm = function(picker)
    local item = picker:current()
    if item then
      picker:close()
      vim.schedule(function()
        Cli.ask({ prompt = item.text })
      end)
    end
  end,
}

return M
