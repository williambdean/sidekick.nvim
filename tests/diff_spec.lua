---@module 'luassert'

local tokenize = require("sidekick.nes.diff").tokenize

describe("tokenize", function()
  -- should split a string in alpha / non-alpha parts
  local cases = {
    { "abcd", { "abcd" } },
    { "abcd ", { "abcd", " " } },
    { " ", { " " } },
    { "abcd.", { "abcd", "." } },
    { "abcd.?", { "abcd", ".", "?" } },
    { "abc123", { "abc123" } },
    { "123abc", { "123abc" } },
    { "abc 123", { "abc", " ", "123" } },
    { "abc\t123", { "abc", "\t", "123" } },
    { "abc\n123", { "abc", "\n", "123" } },
    { "abc.def", { "abc", ".", "def" } },
    { "abc.def.ghi", { "abc", ".", "def", ".", "ghi" } },
    { "abc_def", { "abc_def" } },
    { "abc-def", { "abc", "-", "def" } },
    { "abc+def", { "abc", "+", "def" } },
    { "abc*def", { "abc", "*", "def" } },
    { "abc/def", { "abc", "/", "def" } },
    { "abc=def", { "abc", "=", "def" } },
    {
      'local diff = require("sidekick.nes.diff").diff(edit)',
      {
        "local",
        " ",
        "diff",
        " ",
        "=",
        " ",
        "require",
        "(",
        '"',
        "sidekick",
        ".",
        "nes",
        ".",
        "diff",
        '"',
        ")",
        ".",
        "diff",
        "(",
        "edit",
        ")",
      },
    },
  }

  for _, case in ipairs(cases) do
    it(case[1] .. " => " .. vim.inspect(case[2]), function()
      assert.are.same(case[2], tokenize(case[1]))
    end)
  end
end)
