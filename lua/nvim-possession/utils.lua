local M = {}

---return the list of files in the session
---@param file string
---@return table
M.session_files = function(file)
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
	for _, file in ipairs(vim.fn.readdir(sessions_path)) do
		for line in io.lines(sessions_path .. file) do
			if string.find(line, dir_pat) then
				session_dir = vim.fs.normalize(line:gsub("cd%s*", ""))
				if session_dir == vim.fn.getcwd() then
					return file
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

return M
