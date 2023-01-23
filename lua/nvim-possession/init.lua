local config = require("nvim-possession.config")
local ui = require("nvim-possession.ui")
local utils = require("nvim-possession.utils")

local M = {}

---expose the following interfaces:
---require("nvim-possession").new()
---require("nvim-possession").list()
---require("nvim-possession").update()
---require("nvim-possession").status()
---@param user_opts table
M.setup = function(user_opts)
	local fzf_ok, fzf = pcall(require, "fzf-lua")
	if not fzf_ok then
		print("fzf-lua required as dependency")
		return
	end

	local user_config = vim.tbl_deep_extend("force", config, user_opts or {})

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
			utils.autoswitch(user_config)
		end
		vim.cmd.source(session)
		vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session)
		if type(user_config.post_hook) == "function" then
			user_config.post_hook()
		end
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
			user_config = user_config,
			prompt = user_config.sessions.sessions_icon .. "sessions:",
			file_icons = false,
			show_cwd_header = false,
			preview_opts = "nohidden",

			previewer = ui.session_previewer,
			winopts = user_config.fzf_winopts,
			cwd = user_config.sessions.sessions_path,
			actions = {
				["default"] = M.load,
				["ctrl-x"] = { M.delete, fzf.actions.resume },
			},
		})
	end

	if user_config.autoload and vim.fn.argc() == 0 then
		utils.autoload(user_config)
	end

	if user_config.autosave then
		local autosave_possession = vim.api.nvim_create_augroup("AutosavePossession", {})
		vim.api.nvim_clear_autocmds({ group = autosave_possession })
		vim.api.nvim_create_autocmd("VimLeave", {
			group = autosave_possession,
			desc = "📌 save session on VimLeave",
			callback = function()
				utils.autosave(user_config)
			end,
		})
	else
	end
end

return M
