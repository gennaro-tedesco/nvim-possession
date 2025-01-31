describe("test matching sorting functions", function()
	local sort
	local sessions, time_sorted_sessions

	setup(function()
		sort = require("nvim-possession.sorting")
		sessions = {
			{ name = "aaa", mtime = { sec = 0, nsec = 1 } },
			{ name = "zzz", mtime = { sec = 0, nsec = 2 } },
		}
		time_sorted_sessions =
			{ { name = "zzz", mtime = { sec = 0, nsec = 2 } }, { name = "aaa", mtime = { sec = 0, nsec = 1 } } }
	end)

	teardown(function()
		sort = nil
	end)

	it("time sorting", function()
		table.sort(sessions, sort.time_sort)
		assert.same(time_sorted_sessions, sessions)
	end)
end)
