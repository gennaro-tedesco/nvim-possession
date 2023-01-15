local M = {}

M.sessions = {
  -- sessions_path = vim.fn.stdpath("data") .. "/sessions/",
  sessions_path = "/home/singularis/.config/nvim/misc/sessions/",
  sessions_variable = "session",
  sessions_icon = "📌",
}

M.dressing = true
M.autoload = false
M.viewer = "telescope"

M.telescope = {
  theme = "get_dropdown",
}

M.fzf_winopts = {
  hl = { normal = "Normal" },
  border = "rounded",
  height = 0.5,
  width = 0.25,
  preview = {
    horizontal = "down:40%",
  },
}

return M
