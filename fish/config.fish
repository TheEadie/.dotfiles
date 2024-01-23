# Get Brew apps on $PATH
eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# Add to $PATH
fish_add_path -P "$HOME/.dotnet"
fish_add_path -P "$HOME/.dotnet/tools"
fish_add_path -P "$HOME/.cargo/bin"

# Aliases
if type -q eza; alias ls="eza"; end
if type -q eza; alias la="eza -a"; end
if type -q eza; alias ll="eza -l"; end
if type -q nvim; alias vim="nvim"; end
alias cls="clear"
alias k="kubectl"
alias kc="kubectx"
alias kn="kubens"
alias d="docker"
alias rc="rgclone"

alias gs="git status"
alias gd="git diff"

# Environment variables
set -gx BAT_THEME "Dracula"
set -gx RGCLONE_API_ENDPOINT "https://clone-internal.red-gate.com:8132/"

# Start Starship
starship init fish | source
