local M = {}

local utils = require("nvim-possession.utils")
local config = require("nvim-possession.config")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local previewers = require("telescope.previewers")
local themes = require("telescope.themes")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---expose the following interfaces:
---require("nvim-possession").new()
---require("nvim-possession").list()
---require("nvim-possession").update()
---require("nvim-possession").status()
---@param user_opts table
M.setup = function(user_opts)
	local user_config = vim.tbl_deep_extend("force", config, user_opts or {})

	if user_config.viewer == "fzf" then
		local ok_fzf = pcall(require, "fzf-lua")
		if not ok_fzf then
			print("fzf-lua required as dependency")
			return
		end
	else
		local ok_telescope = pcall(require, "telescope")
		if not ok_telescope then
			print("telescope required as dependency")
			return
		end
	end

	---save current session if session path exists
	---return if path does not exist
	M.new = function()
		if vim.fn.finddir(user_config.sessions.sessions_path) == "" then
			print("sessions_path does not exist.")
			return
		end

		local function create_session(name)
			if next(vim.fs.find(name, { path = user_config.sessions.sessions_path })) == nil then
				vim.cmd.mksession({ args = { user_config.sessions.sessions_path .. name } })
				vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(name)
				print("Saved in: " .. user_config.sessions.sessions_path .. name)
			else
				print("Session already exists.")
			end
		end

		if user_config.dressing then
			vim.ui.input({ prompt = "Session name: " }, function(name)
				if name ~= "" then
					create_session(name)
				end
			end)
		else
			local name = vim.fn.input("Session name: ")
			create_session(name)
		end
	end

	---update loaded session with current status
	M.update = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		if cur_session ~= nil then
			local confirm = vim.fn.confirm("Overwrite session?", "&Yes\n&No", 2)
			if confirm ~= 1 then
				return
			end

			vim.cmd.mksession({ args = { user_config.sessions.sessions_path .. cur_session }, bang = true })
			print("Updated session: " .. cur_session .. ".")
		else
			print("No session loaded.")
		end
	end

	M.autoload = function()
		local session = utils.session_in_cwd(user_config.sessions.sessions_path)
		if session ~= nil then
			vim.cmd.source(user_config.sessions.sessions_path .. session)
			vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session)
		end
	end

	if user_config.autoload and vim.fn.argc() == 0 then
		M.autoload()
	end

	---get global variable with session name: useful for statusbar components
	---@return string|nil
	M.status = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		return cur_session ~= nil and user_config.sessions.sessions_icon .. " " .. cur_session or nil
	end

	---delete selected session
	---@param selected string
	M.delete_fzf = function(selected)
		local session = user_config.sessions.sessions_path .. selected[1]
		local confirm = vim.fn.confirm("Delete session?", "&Yes\n&No", 2)

		if confirm ~= 1 then
			return
		end

		os.remove(session)
		print("Deleted " .. session .. ".")
		if vim.g[user_config.sessions.sessions_variable] == vim.fs.basename(session) then
			vim.g[user_config.sessions.sessions_variable] = nil
		end
	end

	---delete selected session
	---@param prompt_bufnr table
	M.delete_telescope = function(prompt_bufnr)
		actions.move_selection_next(prompt_bufnr)

		local selected = action_state.get_selected_entry()
		local session = user_config.sessions.sessions_path .. selected["display"]

		os.remove(session)
		print("Deleted " .. session .. ".")
		if vim.g[user_config.sessions.sessions_variable] == vim.fs.basename(session) then
			vim.g[user_config.sessions.sessions_variable] = nil
		end
	end

	---load selected session
	---@param selected string
	M.load_fzf = function(selected)
		local session = user_config.sessions.sessions_path .. selected[1]
		vim.cmd.source(session)
		vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session)
	end

	---load selected session
	---@param prompt_bufnr table
	M.load_telescope = function(prompt_bufnr)
		local selected = action_state.get_selected_entry()
		local session = user_config.sessions.sessions_path .. selected["display"]

		actions.close(prompt_bufnr)
		vim.cmd.source(session)
		vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session)
	end

	---list all existing sessions and their files
	---return fzf picker
	M.list_fzf = function()
		local iter = vim.loop.fs_scandir(user_config.sessions.sessions_path)
		local next = vim.loop.fs_scandir_next(iter)
		if next == nil then
			print("No saved sessions.")
			return
		end

		fzf = require("fzf-lua")
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

		fzf.config.set_action_helpstr(M.load_fzf, "load-session")

		return fzf.files({
			prompt = user_config.sessions.sessions_icon .. " Sessions:",
			file_icons = false,
			show_cwd_header = false,
			preview_opts = "nohidden",

			previewer = session_previewer,
			winopts = user_config.fzf_winopts,
			cwd = user_config.sessions.sessions_path,
			actions = {
				["default"] = M.load_fzf,
				["ctrl-x"] = { M.delete_fzf, fzf.actions.resume },
			},
		})
	end

	---list all existing sessions and their files
	---return telescope picker
	M.list_telescope = function()
		local sessions = utils.sessions(user_config.sessions.sessions_path)

		local opts = {
			sorting_strategy = "ascending",
			sorter = sorters.get_generic_fuzzy_sorter({}),
			prompt_title = user_config.sessions.sessions_icon .. " Sessions",

			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", M.load_telescope)
				map("i", "<C-x>", M.delete_telescope)
				return true
			end,

			finder = finders.new_table({
				results = sessions,
				entry_maker = function(item)
					return {
						value = item,
						ordinal = item,
						display = item,
					}
				end,
			}),

			previewer = previewers.new_buffer_previewer({
				title = "Files",
				define_preview = function(self, entry, _)
					local session = entry.value
					local files = utils.session_files(user_config.sessions.sessions_path .. session)

					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, files)
				end,
			}),
		}

		local theme = themes[user_config.telescope.theme]()
		return pickers.new(theme, opts)
	end

	---list all existing sessions and their files
	M.list = function()
		if user_config.viewer == "fzf" then
			M.list_fzf()
		elseif user_config.viewer == "telescope" then
			M.list_telescope():find()
		else
			print("I don't know what you want me to do. Please set `viewer` to be either `telescope` or `fzf`.")
		end
	end
end

return M
