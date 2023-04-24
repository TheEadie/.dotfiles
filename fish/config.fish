# Get Brew apps on $PATH
eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# Add to $PATH
fish_add_path -P "$HOME/.dotnet"

# Aliases
if type -q exa; alias ls="exa"; end
if type -q exa; alias la="exa -a"; end
if type -q nvim; alias vim="nvim"; end
alias cls="clear"
alias k="kubectl"
alias kc="kubectx"
alias kn="kubens"
alias d="docker"
alias s="spawnctl"

alias gs="git status"
alias gd="git diff"

# Environment variables
set -gx BAT_THEME "Dracula"
set -gx RGCLONE_API_ENDPOINT "https://clone-internal.red-gate.com:8132/"

# Start Starship
starship init fish | source
