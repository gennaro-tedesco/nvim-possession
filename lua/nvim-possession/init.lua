local config = require("nvim-possession.config")
local utils = require("nvim-possession.utils")

local ok, fzf = pcall(require, "fzf-lua")
if not ok then
	print("fzf-lua required as dependency")
end

local M = {}

M.setup = function(opts)
	local user_config = vim.tbl_deep_extend("force", config, opts or {})

	M.list = function()
		local iter = vim.loop.fs_scandir(user_config.sessions.sessions_path)
		local next = vim.loop.fs_scandir_next(iter)
		if next == nil then
			print("no saved sessions")
			return
		end

		return fzf.files({
			prompt = "sessions:",
			file_icons = false,
			show_cwd_header = false,
			previewer = utils.session_previewer,
			preview_opts = "nohidden",

			winopts = user_config.fzf_winopts,
			cwd = user_config.sessions_path,
		})
	end
end

return M
