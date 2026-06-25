# Get Brew apps on $PATH
eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# Add to $PATH
fish_add_path -P "$HOME/.dotnet"
fish_add_path -P "$HOME/.dotnet/tools"
fish_add_path -P "$HOME/.cargo/bin"
fish_add_path -P "$HOME/.local/bin"
fish_add_path -P "/usr/lib/jvm/temurin-25-jdk-amd64/bin"

# Only in WSL
if test -r /proc/version; and string match -q "*microsoft*" (cat /proc/version)
    # Fix Wayland on WSL
    ln -sf  /mnt/wslg/runtime-dir/wayland-* $XDG_RUNTIME_DIR

    function cursor
        /mnt/c/Users/david.eadie/AppData/Local/Programs/Cursor/Cursor.exe $argv >/dev/null 2>&1 &
    end
    function code
        /mnt/c/Users/david.eadie/AppData/Local/Programs/Microsoft\ VS\ Code/Code.exe $argv >/dev/null 2>&1 &
    end

    # Claude Code WSL2 fix - remove WindowsPowerShell from PATH
    set -gx PATH (string match -v '*WindowsPowerShell*' $PATH)
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

alias c="claude"

alias gs="git status"
alias gd="git diff"
alias gg="git graph"

# Environment variables
set -gx BAT_THEME "Dracula"
set -gx RGCLONE_API_ENDPOINT "https://clone-internal.red-gate.com:8132/"
set -gx JAVA_HOME /usr/lib/jvm/temurin-25-jdk-amd64

# .NET SDK location (so build scripts/tools that read these env vars find it)
set -gx DOTNET_ROOT "$HOME/.dotnet"
set -gx DOTNET_PATH "$HOME/.dotnet"

# Activate a default node via nvm on every interactive shell.
# (conf.d/nvm.fish is lazy and only auto-activates when nvm_default_version is set.)
if status is-interactive
    nvm use --silent lts 2>/dev/null
end

# Start Starship
starship init fish | source

