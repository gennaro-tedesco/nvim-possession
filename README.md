<h1 align="center">
  <br>
  <img width="250" height="250" src="https://user-images.githubusercontent.com/15387611/212337464-ef0a605f-378b-4a6f-aed2-1b6598b28348.png">
  <br>
  nvim-possession
  <br>
</h1>

<h2 align="center">
  <a href="#" onclick="return false;">
    <img alt="PR" src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat"/>
  </a>
  <a href="#" onclick="return false;">
    <img alt="lua" src="https://img.shields.io/badge/lua-%232C2D72.svg?&style=flat&logo=lua&logoColor=white"/>
  </a>
  <a href="https://github.com/gennaro-tedesco/nvim-possession/releases">
    <img alt="releases" src="https://img.shields.io/github/release/gennaro-tedesco/nvim-possession"/>
  </a>
</h2>

<h4 align="center">No-nonsense session manager</h4>

You are puzzled by neovim sessions and are not using them, are you? Start your pos-sessions journey, fear no more!

This plugin is a no-nonsense session manager built on top of [fzf-lua](https://github.com/ibhagwan/fzf-lua) (required) that makes managing sessions quick and visually appealing: dynamically browse through your existing sessions, create new ones, update and delete with a statusline component to remind you of where you are. See for yourself:

![demo](https://user-images.githubusercontent.com/15387611/211946693-7c0a8f00-4ed8-4142-a8aa-a4dc75f42841.gif)

## 🔌 Installation and quickstart

Install `nvim-possession` with your favourite plugin manager (`fzf-lua` is required) and invoke `require("nvim-possession").setup({})`; in order to avoid conflicts with your own keymaps we do not set any mappings but only expose the interfaces, which means you would need to define them yourself. The suggested quickstart configuration is, for instance

- with [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "gennaro-tedesco/nvim-possession",
    dependencies = {
        "ibhagwan/fzf-lua",
    },
    config = true,
    init = function()
        local possession = require("nvim-possession")
        vim.keymap.set("n", "<leader>sl", function()
            possession.list()
        end)
        vim.keymap.set("n", "<leader>sn", function()
            possession.new()
        end)
        vim.keymap.set("n", "<leader>su", function()
            possession.update()
        end)
    end,
}
```

Exposed interfaces

| function            | description                                                                 | interaction                                                         |
| :------------------ | :-------------------------------------------------------------------------- | :------------------------------------------------------------------ |
| possession.list()   | list all the existing sessions with fzf-lua; preview shows files in session | `<CR>` load selected session<br>`<Ctrl-x>` delete selection session |
| possession.new()    | prompt for name to create new session                                       | session folder must alredy exist, return a message error otherwise  |
| possession.update() | update current session (if new buffers are open)                            | do nothing if no session is loaded                                  |

## 🛠 Usage and advanced configuration

As shown above the main use of the plugin is to show all existing sessions (say via `<leader>sl`) and load the selected one upon `<CR>`. Once a session is loaded a global variable is defined containing the session name (to display in a statusline - see below - or to validate which session is currently active). New sessions can also be created and updated on the fly, and they will show when you next invoke the list.

Default configurations can be found in the [config](https://github.com/gennaro-tedesco/nvim-possession/blob/main/lua/nvim-possession/config.lua) and can be overriden at will by passing them to the `setup({})` function: in particular the default location folder for sessions is `vim.fn.stdpath("data") .. "/sessions/",`. You should not need to change any of the default settings, however if you really want to do so:

```lua

require("nvim-possession").setup({
    sessions = {
        sessions_path = ... -- folder to look for sessions, must be a valid existing path
        sessions_variable = .. -- defines vim.g[sessions_variable] when a session is loaded
        sessions_icon = ...
    },

    autoload = false, -- whether to autoload sessions in the cwd at startup
    autosave = true, -- whether to autosave loaded sessions before quitting
    autoswitch = {
        enable = false -- whether to enable autoswitch
        exclude_ft = {}, -- list of filetypes to exclude from autoswitch
    }

    post_hook = nil -- callback, function to execute after loading a session
                    -- useful to restore file trees, file managers or terminals
                    -- function()
                    --     require('FTerm').open()
                    --     require('nvim-tree').toggle(false, true)
                    -- end

    fzf_winopts = {
        -- any valid fzf-lua winopts options, for instance
        width = 0.5,
        preview = {
            vertical = "right:30%"
        }
    }
})
```

### 🪄 Automagic

If you want to automatically load sessions defined for the current working directory at startup, specify

```lua
require("nvim-possession").setup({
    autoload = true -- default false
})
```

This autoloads sessions when starting neovim without file arguments (i. e. `$ nvim `) and in case such sessions explicitly contain a reference to the current working directory (you must have `vim.go.ssop+=curdir`); this is by design as this plugin intends to be as less invasive as possible.

Sessions are automatically saved before quitting, should buffers be added or removed to them. This defaults to `true` (as it is generally expected behaviour), if you want to opt-out specify

```lua
require("nvim-possession").setup({
    autosave = false -- default true
})
```

When switching between sessions it is often desirable to remove pending buffers belonging to the previous one, so that only buffers with the new session files are loaded. In order to achieve this behaviour specify

```lua
require("nvim-possession").setup({
    autoswitch = {
        enable = true, -- default false
    }
})
```

this option autosaves the previous session and deletes all its buffers before switching to a new one. If there are some filetypes you want to always keep, you may indicate them in

```lua
require("nvim-possession").setup({
    autoswitch = {
        enable = true, -- default false
        exclude_ft = {"...", "..."}, -- list of filetypes to exclude from deletion
    }
})
```

A note on lazy loading: this plugin is extremely light weight and it generally loads in no time: practically speaking there should not be any need to lazy load it on events. If you are however opting in the `autoload = true` feature, notice that by definition such a feature loads the existing session buffers in memory at start-up, thereby also triggering all other buffer related events (especially treesitter); this may result in higher start-up times but is independent of the plugin (you would get the same loading times by manually sourcing the session files).

### Post-hooks

After loading a session you may want to specify additional actions to run that may not be have been saved in the session content: this is often the case for restoring file tree or file managers, or open up terminal windows or fuzzy finders or set specific options. To do so you can use

```lua

require("nvim-possession").setup({
    post_hook = function()
        require("FTerm").open()
        require('nvim-tree').toggle(false, true)
        vim.lsp.buf.format()
    end
})
```

## 🚥 Statusline

You can call `require("nvim-possession").status()` as component in your statusline, for example with `lualine` you would have

```lua

lualine.setup({
	sections = {
		lualine_a = ...
		lualine_b = ...
		lualine_c = { { "filename", path = 1 }, { "require'nvim-possession'.status()" } },
})
```

to display

<p align="center">
  <img width="300" height="100" src="https://user-images.githubusercontent.com/15387611/211811964-037c6233-21d6-4ee1-815c-6da068dd3595.png">
</p>

the component automatically disappears or changes if you delete the current session or switch to another one.

## Feedback

If you find this plugin useful consider awarding it a ⭐, it is a great way to give feedback! Otherwise, any additional suggestions or merge request is warmly welcome!
