" colors
set background=dark
set t_Co=256
colorscheme solarized
syntax on

" file types
filetype plugin indent on

" line numbers
set number

" tab size
set ts=4

" searching
set hlsearch
set incsearch

" indentation
set autoindent smartindent

" backspace
set backspace=indent,eol,start

" remove whitespace from end of lines
nnoremap <F9> :%s/\s*$//<CR>

" enable mouse
set mouse=a

" Show leading whitespace
set list listchars=tab:»·,trail:·,extends:»
