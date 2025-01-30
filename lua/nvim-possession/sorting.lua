local M = {}

---sort sessions by last updated
---@param a table
---@param b table
---@return boolean
M.time_sort = function(a, b)
	if a.mtime.sec ~= b.mtime.sec then
		return a.mtime.sec > b.mtime.sec
	end
	if a.mtime.nsec ~= b.mtime.nsec then
		return a.mtime.nsec > b.mtime.nsec
	end
end

---sort sessions by name
---@param a table
---@param b table
---@return boolean
M.alpha_sort = function(a, b)
	return a.name < b.name
end

return M
