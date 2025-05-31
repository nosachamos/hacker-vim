
return {
    {
        "karb94/neoscroll.nvim",
        lazy = false,
        config = function()
            require("neoscroll").setup({
                duration_multiplier = 0.25,
                easing = 'quadratic',
            })
        end,
    }
}
