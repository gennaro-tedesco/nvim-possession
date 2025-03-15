local M = {}

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

---return the all sessions whose dir corresponds to cwd
---@param sessions_path string
---@return table
M.sessions_in_cwd = function(sessions_path)
	local session_dir, dir_pat = "", "^cd%s*"
	local sessions = {}
	for file, type in vim.fs.dir(sessions_path) do
		if type == "file" then
			for line in io.lines(sessions_path .. file) do
				if string.find(line, dir_pat) then
					session_dir = vim.uv.fs_realpath(vim.fs.normalize((line:gsub("cd%s*", ""))))
					if session_dir == vim.fn.getcwd() then
						local session = M.name_to_session(sessions_path, file)
						if session then
							table.insert(sessions, session)
						end
					end
				end
			end
		end
	end
	return sessions
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

---helper for getting the autoload settings
---@param config table
---@return boolean, boolean
M.autoload_settings = function(config)
	local autoload, autoload_prompt = false, false
	if type(config.autoload) == "boolean" then
		autoload = config.autoload
	elseif type(config.autoload) == "table" then
		autoload = config.autoload.enable
		autoload_prompt = config.autoload.prompt
	end
	return autoload, autoload_prompt
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
	vim.cmd.write()
	M.autosave(config)
	vim.cmd.bufdo("e")
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

---converts a session name into a session object, containing the name and
---last modified time.
---@param sessions_path string
---@param name string
---@return table | nil
M.name_to_session = function(sessions_path, name)
	local stat = vim.uv.fs_stat(sessions_path .. name)
	if stat then
		return { name = name, mtime = stat.mtime }
	end
	return nil
end

return M
