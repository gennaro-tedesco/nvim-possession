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

---return the first session whose dir corresponds to cwd
---@param sessions_path string
---@return string|nil
M.session_in_cwd = function(sessions_path)
	local session_dir, dir_pat = "", "^cd%s*"
	for file, type in vim.fs.dir(sessions_path) do
		if type == "file" then
			for line in io.lines(sessions_path .. file) do
				if string.find(line, dir_pat) then
					session_dir = vim.uv.fs_realpath(vim.fs.normalize((line:gsub("cd%s*", ""))))
					if session_dir == vim.fn.getcwd() then
						return file
					end
				end
			end
		end
	end
	return nil
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

---if any of the existing sessions contains the cwd
---then load it on startup directly
---@param config table
M.autoload = function(config)
	local session = M.session_in_cwd(config.sessions.sessions_path)
	if session ~= nil then
		vim.cmd.source(config.sessions.sessions_path .. session)
		vim.g[config.sessions.sessions_variable] = vim.fs.basename(session)
	end
	if type(config.post_hook) == "function" then
		config.post_hook()
	end
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

return M
