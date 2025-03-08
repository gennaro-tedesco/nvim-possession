local config = require("nvim-possession.config")
local ui = require("nvim-possession.ui")
local utils = require("nvim-possession.utils")
local sort = require("nvim-possession.sorting")

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

	M.create = function(session_name)
		if session_name == "" then
			print("Invalid session name")
			return
		end

		print("💾 session name is : " .. session_name)
		local session_file = user_config.sessions.sessions_path .. session_name
		print("💾 Session file is: " .. session_file)

		-- Check if session already exists
		if next(vim.fs.find(session_name, { path = user_config.sessions.sessions_path })) == nil then
			vim.cmd.mksession({ args = { session_file } })
			vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session_name)
			print("💾 Session saved in: " .. session_file)
		else
			print("⚠️ Session '" .. session_name .. "' already exists")
		end
	end

	fzf.config.set_action_helpstr(M.new, "new-session")

	vim.api.nvim_create_user_command("CreateSession", function(opts)
		local session_name = opts.args
		if session_name == "" then
			print("❌ Please provide a session name.")
			return
		end

		-- Call the session creation function
		M.create(session_name)
	end, { nargs = 1 }) -- `nargs = 1` ensures exactly one argument is required

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
	M.delete_selected = function(selected)
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
	fzf.config.set_action_helpstr(M.delete_selected, "delete-session")

	--delete current active session
	M.delete = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		if cur_session ~= nil then
			local confirm = vim.fn.confirm("delete session " .. cur_session .. "?", "&Yes\n&No", 2)
			if confirm == 1 then
				local session_path = user_config.sessions.sessions_path .. cur_session
				os.remove(session_path)
				print("deleted " .. session_path)
				if vim.g[user_config.sessions.sessions_variable] == vim.fs.basename(session_path) then
					vim.g[user_config.sessions.sessions_variable] = nil
				end
			end
		else
			print("no active session")
		end
	end

	---list all existing sessions and their files
	---return fzf picker
	M.list = function()
		local iter = vim.uv.fs_scandir(user_config.sessions.sessions_path)
		if iter == nil then
			print("session folder " .. user_config.sessions.sessions_path .. " does not exist")
			return
		end
		local next = vim.uv.fs_scandir_next(iter)
		if next == nil then
			print("no saved sessions")
			return
		end

		local function list_sessions(fzf_cb)
			local sessions = {}
			for name, type in vim.fs.dir(user_config.sessions.sessions_path) do
				if type == "file" then
					local stat = vim.uv.fs_stat(user_config.sessions.sessions_path .. name)
					if stat then
						table.insert(sessions, { name = name, mtime = stat.mtime })
					end
				end
			end
			table.sort(sessions, function(a, b)
				if type(user_config.sort) == "function" then
					return user_config.sort(a, b)
				else
					return sort.alpha_sort(a, b)
				end
			end)
			for _, sess in ipairs(sessions) do
				fzf_cb(sess.name)
			end
			fzf_cb()
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
				["ctrl-x"] = { M.delete_selected, fzf.actions.resume, header = "delete session" },
				["ctrl-n"] = { fn = M.new, header = "new session" },
			},
		}
		opts = require("fzf-lua.config").normalize_opts(opts, {})
		opts = require("fzf-lua.core").set_header(opts, { "actions" })
		fzf.fzf_exec(list_sessions, opts)
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
			callback = function() utils.autosave(user_config) end,
		})
	end
end

return M
