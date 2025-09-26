---@module 'luassert'

local line_diff = require("sidekick.nes.diff").line_diff

describe("line_diff", function()
  local cases = {
    {
      name = "returns bounds past the end when lines match",
      a = "hello",
      b = "hello",
      expected = { 6, 5, 5 },
    },
    {
      name = "detects a single character replacement",
      a = "abcde",
      b = "abXde",
      expected = { 3, 3, 3 },
    },
    {
      name = "captures inserted span in new line",
      a = "abc",
      b = "abXc",
      expected = { 3, 2, 3 },
    },
    {
      name = "captures deleted span from original line",
      a = "abXc",
      b = "abc",
      expected = { 3, 3, 2 },
    },
    {
      name = "starts diff at first character when prefixes differ",
      a = "xyz",
      b = "abc",
      expected = { 1, 3, 3 },
    },
  }

  for _, case in ipairs(cases) do
    it(case.name, function()
      local from, to_a, to_b = line_diff(case.a, case.b)
      assert.are.same(case.expected, { from, to_a, to_b })
    end)
  end
end)
