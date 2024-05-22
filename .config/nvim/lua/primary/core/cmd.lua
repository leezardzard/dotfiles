-- To prevent telescope todo cmd not working with neo-tree cause wrong current directory
-- ref: https://stackoverflow.com/questions/78325836/todo-comments-nvim-todotelescope-is-searching-for-todo-comments-in-all-of-my-f
vim.cmd([[ autocmd BufEnter * silent! lcd %:p:h ]]) 
