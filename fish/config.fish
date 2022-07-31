eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)

if status is-interactive
and not set -q TMUX
    exec tmux
end

starship init fish | source