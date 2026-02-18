# Get Brew apps on $PATH
eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# Add to $PATH
fish_add_path -P "$HOME/.dotnet"
fish_add_path -P "$HOME/.dotnet/tools"
fish_add_path -P "$HOME/.cargo/bin"

# Only in WSL
if test -r /proc/version; and string match -q "*microsoft*" (cat /proc/version)
    function cursor
        /mnt/c/Users/david.eadie/AppData/Local/Programs/Cursor/Cursor.exe $argv >/dev/null 2>&1 &
    end
    function code
        /mnt/c/Users/david.eadie/AppData/Local/Programs/Microsoft\ VS\ Code/Code.exe $argv >/dev/null 2>&1 &
    end
end

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

alias yolo="claude --dangerously-skip-permissions"

alias gs="git status"
alias gd="git diff"
alias gg="git graph"

# Environment variables
set -gx BAT_THEME "Dracula"
set -gx RGCLONE_API_ENDPOINT "https://clone-internal.red-gate.com:8132/"

# Start Starship
starship init fish | source

# Fix Wayland on WSL
ln -sf  /mnt/wslg/runtime-dir/wayland-* $XDG_RUNTIME_DIR/