set nocompatible
set number
set cursorline
set shiftwidth=4
set tabstop=4
set expandtab
filetype on
filetype plugin on
filetype indent on
if v:version < 802
    packadd! dracula
endif
syntax on
colorscheme dracula
autocmd FileType gitcommit exec 'au VimEnter * startinsert'
