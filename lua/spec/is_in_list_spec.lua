describe("test matching is_in_list", function()
	local utils
	local s, l, r

	setup(function()
		utils = require("nvim-possession.utils")
		s = "lua"
		r = "rust"
		l = { "python", "lua", "go", "vim" }
	end)

	teardown(function()
		utils = nil
	end)

	it("positive match", function()
		assert.is_true(utils.is_in_list(s, l))
	end)
	it("negative match", function()
		assert.is_false(utils.is_in_list(r, l))
	end)
end)
