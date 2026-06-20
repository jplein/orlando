-- Orlando autoloads here. Registers activation autocmds once.

if vim.g.loaded_orlando then
  return
end
vim.g.loaded_orlando = true

local group = vim.api.nvim_create_augroup("orlando", { clear = true })

-- FileType: filetype just became known -> set buffer-local + window options.
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "*",
  callback = function(args)
    require("orlando").attach(args.buf)
  end,
})

-- BufWinEnter: buffer shown in a (possibly new) window -> reapply window opts.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  callback = function(args)
    require("orlando").attach(args.buf)
  end,
})
