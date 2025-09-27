# 🤖 `sidekick.nvim`

**sidekick.nvim** brings GitHub Copilot "Next Edit Suggestions" (NES) to Neovim with a
native diff preview, jump helpers, and status reporting. The plugin sits on top of
Copilot's LSP server and turns AI edits into something you can inspect, navigate, and
apply without leaving the buffer.

> [!WARNING]  
> **Status**: Early preview. The API is still settling; expect breaking changes while
> Copilot's inline edit endpoints evolve.

<img width="1474" height="971" alt="image" src="https://github.com/user-attachments/assets/6f4ff1ad-aa47-4219-8a01-69bdf29e0d8a" />

## ✨ Features

- 🪄 **Live inline edits** – automatically request Copilot NES suggestions on cursor
  movement or insert mode transitions.
- 🧭 **Diff-aware navigation** – render inline or block-style diffs with Treesitter
  highlights, signs, and jump helpers.
- 🎯 **One-keystroke apply** – accept all pending edits with a single mapping while
  keeping jumplist history intact.
- 🧹 **Smart clearing** – automatically retract suggestions when you resume typing,
  save the buffer, or hit `<Esc>`.
- 📡 **Status helpers** – expose `sidekick.status.get()` so statuslines/widgets can show
  Copilot connectivity, activity state, and messages.

## 📋 Requirements

- **Neovim** `>= 0.11.2` or newer
- The official **Copilot LSP** server, enabled with `vim.lsp.enable`
  **TIP:** can be installed with [mason-lspconfig.nvim](https://github.com/mason-org/mason-lspconfig.nvim)
- A working `lsp/copilot.lua` configuration.
  **TIP:** Included in [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)

## 📦 Installation

Install with your favorite manager. With [lazy.nvim](https://github.com/folke/lazy.nvim):

<!-- setup_base:start -->

```lua
{
  "folke/sidekick.nvim",
  opts = {
    -- add any options here
  },
  keys = {
    {
      "<tab>",
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if not require("sidekick").nes_jump_or_apply() then
          return "<Tab>" -- fallback to normal tab
        end
      end,
      expr = true,
      desc = "Goto/Apply Next Edit Suggestion",
    },
  },
}
```

<!-- setup_base:end -->

### Integrate `<Tab>` in insert mode with [blink.cmp](https://github.com/saghen/blink.cmp)

<!-- setup_blink:start -->

```lua
{
  "saghen/blink.cmp",
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {

    keymap = {
      ["<Tab>"] = {
        "snippet_forward",
        function() -- sidekick next edit suggestion
          return require("sidekick").nes_jump_or_apply()
        end,
        function() -- if you are using Neovim's native inline completions
          return vim.lsp.inline_completion.get()
        end,
        "fallback",
      },
    },
  },
}
```

<!-- setup_blink:end -->

### Custom `<Tab>` integration for insert mode

<!-- setup_custom:start -->

```lua
{
  "folke/sidekick.nvim",
  opts = {
    -- add any options here
  },
  keys = {
    {
      "<tab>",
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if require("sidekick").nes_jump_or_apply() then
          return -- jumped or applied
        end

        -- if you are using Neovim's native inline completions
        if vim.lsp.inline_completion.get() then
          return
        end

        -- any other things (like snippets) you want to do on <tab> go here.

        -- fall back to normal tab
        return "<tab>"
      end,
      mode = { "i", "n" },
      expr = true,
      desc = "Goto/Apply Next Edit Suggestion",
    },
  },
}
```

<!-- setup_custom:end -->

After installation sign in with `:LspCopilotSignIn` if prompted.

## ⚙️ Configuration

The module ships with safe defaults and exposes everything through
`require("sidekick").setup({ ... })`.

<details>
<summary>Default settings</summary>

<!-- config:start -->

```lua
---@class sidekick.Config
local defaults = {
  jump = {
    jumplist = true, -- add an entry to the jumplist
  },
  signs = {
    enabled = true, -- enable signs by default
    add = " ",
    change = " ",
    delete = " ",
  },
  nes = {
    debounce = 100,
    trigger = {
      -- events that trigger sidekick next edit suggestions
      events = { "InsertLeave", "TextChanged", "User SidekickNesDone" },
    },
    clear = {
      -- events that clear the current next edit suggestion
      events = { "TextChangedI", "BufWritePre", "InsertEnter" },
      esc = true, -- clear next edit suggestions when pressing <Esc>
    },
    ---@class sidekick.diff.Opts
    ---@field inline? "words"|"chars"|false Enable inline diffs
    diff = {
      inline = "words",
    },
  },
}
```

<!-- config:end -->

</details>

## 🚀 Usage

- Copilot NES requests run automatically when you leave insert mode,
  modify text in normal mode, or after applying an edit.
- Use the helper functions to control suggestions manually:
  - `require("sidekick.nes").update()` – request fresh edits for the current buffer.
  - `require("sidekick.nes").jump()` – move the cursor to the first suggested hunk.
  - `require("sidekick.nes").apply()` – apply all pending edits and emit the
    `User SidekickNesDone` autocmd.
  - `require("sidekick").clear()` – cancel requests and hide overlays.
  - `require("sidekick.nes").have()` – check if any edits are active in the buffer.
- Hook into the `User` autocmd (`pattern = "SidekickNesDone"`) to run follow-up logic
  after an edit has been applied.

## 📟 Statusline integration

Example for [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim):

<!-- setup_lualine:start -->

```lua
{
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    table.insert(opts.sections.lualine_c, {
      function()
        return " "
      end,
      color = function()
        local status = require("sidekick.status").get()
        if status then
          return status.kind == "Error" and "DiagnosticError" or status.busy and "DiagnosticWarn" or "Special"
        end
      end,
      cond = function()
        local status = require("sidekick.status")
        return status.get() ~= nil
      end,
    })
  end,
}
```

<!-- setup_lualine:end -->

The handler automatically notifies you when authentication is required.

## 📄 License

Released under the [MIT License](LICENSE).
