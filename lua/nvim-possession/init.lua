local ok, fzf = pcall(require, "fzf-lua")
if not ok then
	print("fzf-lua required as dependency")
end

local config = require("nvim-possession.config")
local utils = require("nvim-possession.utils")

local M = {}

---expose the following interfaces:
---require("nvim-possession").new()
---require("nvim-possession").list()
---require("nvim-possession").update()
---require("nvim-possession").status()
---@param user_opts table
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

	---update loaded session with current status
	M.update = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		if cur_session ~= nil then
			local confirm = vim.fn.confirm("overwrite session?", "&Yes\n&No", 2)
			if confirm == 1 then
				vim.cmd.mksession({ args = { user_config.sessions.sessions_path .. cur_session }, bang = true })
				print("updated session: " .. cur_session)
			end
		else
			print("no session loaded")
		end
	end

	---load selected session
	---@param selected string
	M.load = function(selected)
		local session = user_config.sessions.sessions_path .. selected[1]
		if user_config.autoswitch.enable and vim.g[user_config.sessions.sessions_variable] ~= nil then
			M.autoswitch()
		end
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

	---if any of the existing sessions contains the cwd
	---then load it on startup directly
	M.autoload = function()
		local session = utils.session_in_cwd(user_config.sessions.sessions_path)
		if session ~= nil then
			vim.cmd.source(user_config.sessions.sessions_path .. session)
			vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session)
		end
	end

	---check if a session is loaded and save it automatically
	---without asking for prompt
	M.autosave = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		if cur_session ~= nil then
			vim.cmd.mksession({ args = { user_config.sessions.sessions_path .. cur_session }, bang = true })
		end
	end

	---before switching session perform the following:
	---1) autosave current session
	---2) save and close all modifiable buffers
	M.autoswitch = function()
		vim.cmd.write()
		M.autosave()
		vim.cmd.bufdo("e")
		local buf_list = vim.tbl_filter(function(buf)
			return vim.api.nvim_buf_is_valid(buf)
				and vim.api.nvim_buf_get_option(buf, "buflisted")
				and vim.api.nvim_buf_get_option(buf, "modifiable")
				and not utils.is_in_list(vim.api.nvim_buf_get_option(buf, "filetype"), config.autoswitch.exclude_ft)
		end, vim.api.nvim_list_bufs())
		for _, buf in pairs(buf_list) do
			vim.cmd("bd " .. buf)
		end
	end

	if user_config.autoload and vim.fn.argc() == 0 then
		M.autoload()
	end

	if user_config.autosave then
		local autosave_possession = vim.api.nvim_create_augroup("AutosavePossession", {})
		vim.api.nvim_clear_autocmds({ group = autosave_possession })
		vim.api.nvim_create_autocmd("VimLeave", {
			group = autosave_possession,
			desc = "📌 save session on VimLeave",
			callback = function()
				M.autosave()
			end,
		})
	end
end

return M
