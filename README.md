# 🤖 `sidekick.nvim`

**sidekick.nvim** brings GitHub Copilot "Next Edit Suggestions" (NES) to Neovim with a
native diff preview, jump helpers, and status reporting. The plugin sits on top of
Copilot's LSP server and turns AI edits into something you can inspect, navigate, and
apply without leaving the buffer.

> **Status**: Early preview. The API is still settling; expect breaking changes while
> Copilot's inline edit endpoints evolve.

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

- Neovim **0.11.0** or newer (uses the latest LSP tooling like `vim.lsp.config`).
- Access to the official GitHub Copilot LSP (`:LspStart copilot`).
- A working internet connection for Copilot itself.

## 📦 Installation

Install with your favorite manager. With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  {
    "folke/sidekick.nvim",
    event = "VeryLazy",
    opts = {
      -- tweak defaults here
    },
    keys = {
      {
        "<leader>ca",
        function()
          require("sidekick.nes").apply()
        end,
        desc = "Sidekick: apply next edit",
      },
      {
        "<leader>cj",
        function()
          require("sidekick.nes").jump()
        end,
        desc = "Sidekick: jump to next edit",
      },
      {
        "<leader>cn",
        function()
          require("sidekick.nes").update()
        end,
        desc = "Sidekick: request next edit",
      },
      {
        "<leader>cc",
        function()
          require("sidekick").clear()
        end,
        desc = "Sidekick: clear suggestions",
      },
    },
  },
}
```

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
    ---@class sidekick.diff.Opts: vim.text.diff.Opts
    ---@field inline? boolean Enable inline diffs
    diff = {
      inline = true,
      algorithm = "patience",
      linematch = true,
    },
  },
}
```

<!-- config:end -->

</details>

## 🚀 Usage

- Copilot NES requests run automatically when you leave insert mode or modify text.
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

Query the current Copilot status and show it anywhere:

```lua
local status = require("sidekick.status").get(0)
if status then
  if status.busy then
    return " .."
  end
  if status.kind == "Error" then
    return " Copilot"
  end
  return " " .. (status.message or status.kind)
end
```

The handler automatically notifies you when authentication is required.

## 📄 License

Released under the [MIT License](LICENSE).
