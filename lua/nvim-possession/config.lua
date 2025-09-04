local sort = require("nvim-possession.sorting")

local M = {}

M.sessions = {
	sessions_path = vim.fn.stdpath("data") .. "/sessions/",
	sessions_variable = "session",
	sessions_icon = "📌",
	sessions_prompt = "sessions:",
}

---@type boolean
M.autoload = false
---@type boolean
M.autoprompt = false
---@type boolean
M.autosave = true
M.autoswitch = {
	enable = false,
	exclude_ft = {},
}

---@type function
M.save_hook = nil
---@type function
M.post_hook = nil

---@class possession.Hls
---@field normal? string hl group bg session window
---@field preview_normal? string hl group bg preview window
---@field border? string hl group border session window
---@field preview_border? string hl group border preview window
M.fzf_hls = {
	normal = "Normal",
	preview_normal = "Normal",
	border = "Constant",
	preview_border = "Constant",
}

---@class possession.Winopts
---@field border? string Any of the options of nvim_win_open.border
---@field height? number Height of the fzf window
---@field width? number Width of the fzf window
---@field preview? table
M.fzf_winopts = {
	title = " sessions 📌 ",
	title_pos = "center",
	border = "rounded",
	height = 0.5,
	width = 0.25,
	preview = {
		hidden = "nohidden",
		horizontal = "down:40%",
	},
}

---@class possession.Mapopts
---@field delete? string
---@field rename? string
---@field new? string
M.mappings = {
	action_delete = "ctrl-x",
	action_rename = "ctrl-r",
	action_new = "ctrl-n",
}

---@type function
M.sort = sort.alpha_sort

return M
