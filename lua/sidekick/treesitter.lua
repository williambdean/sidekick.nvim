local M = {}

---@alias sidekick.TSHighlight string | { [1]:string, [2]:string }
---@alias sidekick.TSTextChunk { [1]:string, [2]?:sidekick.TSHighlight }
---@alias sidekick.TSVirtualText sidekick.TSTextChunk[]
---@alias sidekick.TSVirtualLines sidekick.TSVirtualText[]

---@param lines string[]
---@param opts {ft:string, bg?:string}
---@return sidekick.TSVirtualLines
function M.get_virtual_lines(lines, opts)
  local lang = vim.treesitter.language.get_lang(opts.ft)
  local source = table.concat(lines, "\n")
  local parser ---@type vim.treesitter.LanguageTree?
  if lang then
    lang = lang:lower()
    local ok = false
    ok, parser = pcall(vim.treesitter.get_string_parser, source, lang)
    parser = ok and parser or nil
  end

  if not parser then
    return vim.tbl_map(function(line)
      return { { line } }
    end, lines)
  end

  local index = {} ---@type table<number, table<number, string>>

  parser:parse(true)
  parser:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end
    local query = vim.treesitter.query.get(tree:lang(), "highlights")
    -- Some injected languages may not have highlight queries.
    if not query then
      return
    end

    for capture, node, metadata in query:iter_captures(tstree:root(), source) do
      ---@type string
      local name = query.captures[capture]
      if name ~= "spell" then
        local range = { node:range() } ---@type number[]
        local multi = range[1] ~= range[3]
        local text = multi
            and vim.split(vim.treesitter.get_node_text(node, source, metadata[capture]), "\n", { plain = true })
          or {}
        for row = range[1] + 1, range[3] + 1 do
          local first, last = row == range[1] + 1, row == range[3] + 1
          local end_col = last and range[4] or #(text[row - range[1]] or "")
          local col = first and range[2] or 0
          end_col = multi and first and end_col + range[2] or end_col
          local hl_group = "@" .. name .. "." .. lang
          index[row] = index[row] or {}
          for i = col + 1, end_col do
            index[row][i] = hl_group
          end
        end
      end
    end
  end)

  local ret = {} ---@type sidekick.TSVirtualLines
  for i = 1, #lines do
    local line = lines[i]
    local from = 1
    local hl_group = nil ---@type string?

    ---@param to number
    local function add(to)
      if to >= from then
        ret[i] = ret[i] or {}
        local text = line:sub(from, to)
        local hl = opts.bg and { hl_group or "Normal", opts.bg } or hl_group
        if #text > 0 then
          table.insert(ret[i], { text, hl })
        end
      end
      from = to + 1
      hl_group = nil
    end

    for col = 1, #line do
      local hl = index[i] and index[i][col]
      if hl ~= hl_group then
        add(col - 1)
        hl_group = hl
      end
    end
    add(#line)
  end
  return ret
end

--- Highlight leading/trailing whitespace and EOL in virtual lines
---@param virtual_lines sidekick.TSVirtualLines
---@param opts? {leading?:string, trailing?:string}
function M.highlight_ws(virtual_lines, opts)
  opts = opts or {}
  for _, vt in ipairs(virtual_lines) do
    if opts.trailing then
      table.insert(vt, { string.rep(" ", vim.o.columns), opts.trailing })
    end
    if opts.leading then
      local chunk = vt[1]
      if chunk then
        local text = chunk[1]
        local ws = text:match("^%s+")
        if ws then
          local chunk_hl = chunk[2]
          chunk[1] = ws
          chunk[2] = opts.leading
          if #ws < #text then
            table.insert(vt, 2, { text:sub(#ws + 1), chunk_hl })
          end
        else
          chunk[2] = nil
        end
      end
    end
  end
  return virtual_lines
end

return M
