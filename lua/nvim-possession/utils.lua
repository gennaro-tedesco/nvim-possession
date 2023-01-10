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

return M
