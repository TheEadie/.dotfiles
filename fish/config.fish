# Get Brew apps on $PATH
eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)

#Run tmux
if status is-interactive
and not set -q TMUX
    tmux attach -t base || tmux new -s base
end

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

# Start Starship
starship init fish | source
