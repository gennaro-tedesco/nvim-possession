local utils = require("nvim-possession.utils")

local builtin_ok, builtin = pcall(require, "fzf-lua.previewer.builtin")
if not builtin_ok then
	return
end

--- extend fzf builtin previewer
local M = {}
M.session_previewer = builtin.base:extend()

M.session_previewer.new = function(self, o, opts, fzf_win)
	M.session_previewer.super.new(self, o, opts, fzf_win)
	setmetatable(self, M.session_previewer)
	return self
end

M.session_previewer.populate_preview_buf = function(self, entry_str)
	local tmpbuf = self:get_tmp_buffer()
	local files = utils.session_files(self.opts.user_config.sessions.sessions_path .. entry_str)

	vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, files)
	self:set_preview_buf(tmpbuf)
	self.win:update_preview_scrollbar()
end

M.session_previewer.gen_winopts = function(self)
	local new_winopts = {
		wrap = false,
		number = false,
	}
	return vim.tbl_extend("force", self.winopts, new_winopts)
end
return M
