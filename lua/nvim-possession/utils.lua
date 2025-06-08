local sort = require("nvim-possession.sorting")
local M = {}

---return the list of available sessions
---@param user_config table
---@return table
M.list_sessions = function(user_config, cwd)
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
	local session_names = {}
	for _, sess in ipairs(sessions) do
		if cwd then
			if M.is_in_cwd(sess.name, user_config) then
				table.insert(session_names, sess.name)
			end
		else
			table.insert(session_names, sess.name)
		end
	end
	return session_names
end

---return the list of files in the session
---@param file string
---@return table
M.session_files = function(file)
	if vim.fn.isdirectory(file) == 1 then
		return {}
	end
	local lines = {}
	local cwd, cwd_pat = "", "^cd%s*"
	local buf_pat = "^badd%s*%+%d+%s*"
	for line in io.lines(file) do
		if string.find(line, cwd_pat) then
			cwd = line:gsub("%p", "%%%1")
		end
		if string.find(line, buf_pat) then
			lines[#lines + 1] = line
		end
	end
	local buffers = {}
	for k, v in pairs(lines) do
		buffers[k] = v:gsub(buf_pat, ""):gsub(cwd:gsub("cd%s*", ""), ""):gsub("^/?%.?/", "")
	end
	return buffers
end

---checks whether a session is contained in the cwd
---@param session string
---@param user_config table
---@return boolean
M.is_in_cwd = function(session, user_config)
	local session_dir, dir_pat = "", "^cd%s*"
	for file, type in vim.fs.dir(user_config.sessions.sessions_path) do
		if type == "file" and file == session then
			for line in io.lines(user_config.sessions.sessions_path .. file) do
				if string.find(line, dir_pat) then
					session_dir = vim.uv.fs_realpath(vim.fs.normalize((line:gsub("cd%s*", ""))))
					if session_dir == vim.fn.getcwd() then
						return true
					end
				end
			end
		end
	end
	return false
end

---check if an item is in a list
---@param value string
---@param list table
---@return boolean
M.is_in_list = function(value, list)
	for _, v in pairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

---check if a session is loaded and save it automatically
---without asking for prompt
---@param config table
M.autosave = function(config)
	local cur_session = vim.g[config.sessions.sessions_variable]
	if type(config.save_hook) == "function" then
		config.save_hook()
	end
	if cur_session ~= nil then
		vim.cmd.mksession({ args = { config.sessions.sessions_path .. cur_session }, bang = true })
	end
end

---before switching session perform the following:
---1) autosave current session
---2) save and close all modifiable buffers
---@param config table
M.autoswitch = function(config)
    if vim.api.nvim_buf_get_name(0) ~= "" then
        vim.cmd.write()
    end
	M.autosave(config)
    vim.cmd([[silent! bufdo if expand('%') !=# '' | edit | endif]])
	local buf_list = vim.tbl_filter(function(buf)
		return vim.api.nvim_buf_is_valid(buf)
			and vim.api.nvim_buf_get_option(buf, "buflisted")
			and vim.api.nvim_buf_get_option(buf, "modifiable")
			and not M.is_in_list(vim.api.nvim_buf_get_option(buf, "filetype"), config.autoswitch.exclude_ft)
	end, vim.api.nvim_list_bufs())
	for _, buf in pairs(buf_list) do
		vim.cmd("bd " .. buf)
	end
end

return M
