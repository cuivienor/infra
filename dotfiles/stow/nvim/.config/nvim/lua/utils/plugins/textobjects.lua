return {
	textobjects = {
		select = {
			enable = true,
			lookahead = true,

			keymaps = {
				["a="] = { query = "@assignment.outer", desc = "Select outer part of an assignment" },
				["i="] = { query = "@assignment.inner", desc = "Select inner part of an assignment" },
			},
		},
	},
}
