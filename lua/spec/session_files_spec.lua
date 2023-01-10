describe("test matching session files", function()
	local utils
	local test_file, session_files

	setup(function()
		utils = require("nvim-possession.utils")
		test_file = "spec/session_test_file"
		session_files = {
			"nvim/init.lua",
			"nvim/plugin/mappings.vim",
		}
	end)

	teardown(function()
		utils = nil
	end)

	it("positive match", function()
		assert.same(session_files, utils.session_files(test_file))
	end)
end)
