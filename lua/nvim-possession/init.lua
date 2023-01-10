local config = require("nvim-possession.config")
local utils = require("nvim-possession.utils")

local ok, fzf = pcall(require, "fzf-lua")
if not ok then
	print("fzf-lua required as dependency")
end

local builtin = require("fzf-lua.previewer.builtin")

local M = {}

M.setup = function(user_opts)
	local user_config = vim.tbl_deep_extend("force", config, user_opts or {})

	--- extend fzf builtin previewer
	local session_previewer = builtin.base:extend()
	function session_previewer:new(o, opts, fzf_win)
		session_previewer.super.new(self, o, opts, fzf_win)
		setmetatable(self, session_previewer)
		return self
	end

	function session_previewer:populate_preview_buf(entry_str)
		local tmpbuf = self:get_tmp_buffer()
		local buffers = utils.session_files(user_config.sessions.sessions_path .. entry_str)

		vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, buffers)
		self:set_preview_buf(tmpbuf)
		self.win:update_scrollbar()
	end

	function session_previewer:gen_winopts()
		local new_winopts = {
			wrap = false,
			number = false,
		}
		return vim.tbl_extend("force", self.winopts, new_winopts)
	end

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
			previewer = session_previewer,
			preview_opts = "nohidden",

			winopts = user_config.fzf_winopts,
			cwd = user_config.sessions_path,
		})
	end
end

return M
