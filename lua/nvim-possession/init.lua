local config = require("nvim-possession.config")
local utils = require("nvim-possession.utils")

local ok, fzf = pcall(require, "fzf-lua")
if not ok then
	print("fzf-lua required as dependency")
end

local M = {}

M.setup = function(user_opts)
	local user_config = vim.tbl_deep_extend("force", config, user_opts or {})

	--- extend fzf builtin previewer
	local builtin = require("fzf-lua.previewer.builtin")
	local session_previewer = builtin.base:extend()
	function session_previewer:new(o, opts, fzf_win)
		session_previewer.super.new(self, o, opts, fzf_win)
		setmetatable(self, session_previewer)
		return self
	end

	function session_previewer:populate_preview_buf(entry_str)
		local tmpbuf = self:get_tmp_buffer()
		local files = utils.session_files(user_config.sessions.sessions_path .. entry_str)

		vim.api.nvim_buf_set_lines(tmpbuf, 0, -1, false, files)
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

	---get global variable with session name: useful for statusbar components
	---@return string|nil
	M.status = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		return cur_session ~= nil and user_config.sessions.sessions_icon .. cur_session or nil
	end

	---save current session if session path exists
	---return if path does not exist
	M.new = function()
		if vim.fn.finddir(user_config.sessions.sessions_path) == "" then
			print("sessions_path does not exist")
			return
		end

		local name = vim.fn.input("name: ")
		if name ~= "" then
			if next(vim.fs.find(name, { path = user_config.sessions.sessions_path })) == nil then
				vim.cmd.mksession({ args = { user_config.sessions.sessions_path .. name } })
				vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(name)
				print("saved in: " .. user_config.sessions.sessions_path .. name)
			else
				print("session already exists")
			end
		end
	end

	---load selected session
	---@param selected string
	M.load = function(selected)
		local session = user_config.sessions.sessions_path .. selected[1]
		vim.cmd.source(session)
		vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session)
	end
	fzf.config.set_action_helpstr(M.load, "load-session")

	---delete selected session
	---@param selected string
	M.delete = function(selected)
		local session = user_config.sessions.sessions_path .. selected[1]
		local confirm = vim.fn.confirm("delete session?", "&Yes\n&No", 2)
		if confirm == 1 then
			os.remove(session)
			print("deleted " .. session)
			if vim.g[user_config.sessions.sessions_variable] == vim.fs.basename(session) then
				vim.g[user_config.sessions.sessions_variable] = nil
			end
		end
	end
	fzf.config.set_action_helpstr(M.delete, "delete-session")

	---list all existing sessions and their files
	---return fzf picker
	M.list = function()
		local iter = vim.loop.fs_scandir(user_config.sessions.sessions_path)
		local next = vim.loop.fs_scandir_next(iter)
		if next == nil then
			print("no saved sessions")
			return
		end

		return fzf.files({
			prompt = user_config.sessions.sessions_icon .. "sessions:",
			file_icons = false,
			show_cwd_header = false,
			preview_opts = "nohidden",

			previewer = session_previewer,
			winopts = user_config.fzf_winopts,
			cwd = user_config.sessions.sessions_path,
			actions = {
				["default"] = M.load,
				["ctrl-x"] = { M.delete, fzf.actions.resume },
			},
		})
	end
end

return M
