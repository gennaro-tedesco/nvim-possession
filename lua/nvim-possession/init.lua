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
	local user_config = vim.tbl_deep_extend("force", config, user_opts or {})

	local notification_title = user_config.sessions.sessions_icon .. " nvim-possession"
	local fzf_ok, fzf = pcall(require, "fzf-lua")
	if not fzf_ok then
		vim.notify("fzf-lua required as dependency", vim.log.levels.WARN, { title = notification_title })
		return
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
			vim.notify("sessions_path does not exist", vim.log.levels.WARN, { title = notification_title })
			return
		end

		local name = vim.fn.input("name: ")
		if name ~= "" then
			if next(vim.fs.find(name, { path = user_config.sessions.sessions_path })) == nil then
				vim.cmd.mksession({ args = { user_config.sessions.sessions_path .. name } })
				vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(name)
				vim.notify(
					"saved in: " .. user_config.sessions.sessions_path .. name,
					vim.log.levels.INFO,
					{ title = notification_title }
				)
			else
				vim.notify("session already exists", vim.log.levels.INFO, { title = notification_title })
			end
		end
	end
	fzf.config.set_action_helpstr(M.new, "new-session")

	---update loaded session with current status
	M.update = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		if cur_session ~= nil then
			local confirm = vim.fn.confirm("overwrite session?", "&Yes\n&No", 2)
			if confirm == 1 then
				if type(user_config.save_hook) == "function" then
					user_config.save_hook()
				end
				vim.cmd.mksession({ args = { user_config.sessions.sessions_path .. cur_session }, bang = true })
				vim.notify("updated session: " .. cur_session, vim.log.levels.INFO, { title = notification_title })
			end
		else
			vim.notify("no session loaded", vim.log.levels.INFO, { title = notification_title })
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
	M.delete_selected = function(selected)
		local session = user_config.sessions.sessions_path .. selected[1]
		local confirm = vim.fn.confirm("delete session?", "&Yes\n&No", 2)
		if confirm == 1 then
			os.remove(session)
			vim.notify("deleted " .. session, vim.log.levels.INFO, { title = notification_title })
			if vim.g[user_config.sessions.sessions_variable] == vim.fs.basename(session) then
				vim.g[user_config.sessions.sessions_variable] = nil
			end
		end
	end
	fzf.config.set_action_helpstr(M.delete_selected, "delete-session")

	---delete current active session
	M.delete = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		if cur_session ~= nil then
			local confirm = vim.fn.confirm("delete session " .. cur_session .. "?", "&Yes\n&No", 2)
			if confirm == 1 then
				local session_path = user_config.sessions.sessions_path .. cur_session
				os.remove(session_path)
				vim.notify("deleted " .. session_path, vim.log.levels.INFO, { title = notification_title })
				if vim.g[user_config.sessions.sessions_variable] == vim.fs.basename(session_path) then
					vim.g[user_config.sessions.sessions_variable] = nil
				end
			end
		else
			vim.notify("no active session", vim.log.levels.WARN, { title = notification_title })
		end
	end

	---rename selected session
	---@param selected string
	M.rename_selected = function(selected)
		local session_path = user_config.sessions.sessions_path
		local old_name = selected[1]
		local old_file_path = session_path .. old_name
		local new_name = vim.fn.input("Enter new name for the session: ", old_name)

		if new_name and new_name ~= "" then
			local new_file_path = session_path .. new_name
			os.rename(old_file_path, new_file_path)
			vim.notify(
				"Session renamed from " .. old_name .. " to " .. new_name,
				vim.log.levels.INFO,
				{ title = notification_title }
			)
		else
			vim.notify("New name cannot be empty", vim.log.levels.WARN, { title = notification_title })
		end
	end
	fzf.config.set_action_helpstr(M.rename_selected, "rename-session")

	---list all existing sessions and their files
	---@param cwd boolean|nil
	M.list = function(cwd)
		local iter = vim.uv.fs_scandir(user_config.sessions.sessions_path)
		if iter == nil then
			vim.notify(
				"session folder " .. user_config.sessions.sessions_path .. " does not exist",
				vim.log.levels.WARN,
				{ title = notification_title }
			)
			return
		end
		local next_dir = vim.uv.fs_scandir_next(iter)
		if next_dir == nil then
			vim.notify("no saved sessions", vim.log.levels.WARN, { title = notification_title })
			return
		end

		local opts = {
			user_config = user_config,
			prompt = user_config.sessions.sessions_icon .. user_config.sessions.sessions_prompt,
			cwd_prompt = false,
			file_icons = false,
			git_icons = false,
			cwd_header = false,
			no_header = true,

			previewer = ui.session_previewer,
			hls = user_config.fzf_hls,
			winopts = user_config.fzf_winopts,
			cwd = user_config.sessions.sessions_path,
			actions = {
				["enter"] = M.load,
				[user_config.mappings.action_delete] = {
					fn = function(selected)
						M.delete_selected(selected)
						M.list()
					end,
					header = "delete session",
				},
				[user_config.mappings.action_rename] = {
					fn = function(selected)
						M.rename_selected(selected)
						M.list()
					end,
					header = "rename session",
				},
				[user_config.mappings.action_new] = { fn = M.new, header = "new session" },
			},
		}
		opts = require("fzf-lua.config").normalize_opts(opts, {})
		opts = require("fzf-lua.core").set_header(opts)

		---autoload mechanism
		if cwd then
			local sessions_in_cwd = utils.list_sessions(user_config, cwd)
			if next(sessions_in_cwd) == nil then
				return nil
			elseif #sessions_in_cwd == 1 or not user_config.autoprompt then
				vim.schedule(function()
					vim.cmd.source(user_config.sessions.sessions_path .. sessions_in_cwd[1])
					vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(sessions_in_cwd[1])
					if type(user_config.post_hook) == "function" then
						user_config.post_hook()
					end
				end)
				return nil
			end
		end
		---standard list load mechanism
		fzf.fzf_exec(function(fzf_cb)
			for _, sess in ipairs(utils.list_sessions(user_config, cwd)) do
				fzf_cb(sess)
			end
			fzf_cb()
		end, opts)
	end

	if user_config.autoload and vim.fn.argc() == 0 then
		M.list(true)
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
	end
end

return M
