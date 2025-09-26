local Docs = require("lazy.docs")

local M = {}

function M.update()
  local config = Docs.extract("lua/sidekick/config.lua", "\n(--@class sidekick%.Config.-\n})")
  config = config:gsub("%s*debug = false.\n", "\n")
  Docs.save({
    config = config,
  })
end

M.update()
print("Updated docs")

return M
