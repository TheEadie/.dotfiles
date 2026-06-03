# Install Brew and Fish
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install fish
brew install starship

# Clean up
rm ~/.gitconfig
rm ~/.gitconfig.unix
rm ~/.gitconfig.wsl
rm ~/.gitconfig.redgate
rm ~/.config/fish/config.fish
rm ~/.config/starship.toml
rm ~/.tmux.conf
rm ~/.vimrc
rm -rf ~/.claude/skills
rm -rf ~/.claude/commands
rm -rf ~/.claude/agents
rm -rf ~/.claude/scripts
rm -f ~/.claude/settings.json

# Install Dracula VIM theme
mkdir -p ~/.vim/pack/themes/start
git clone https://github.com/dracula/vim.git ~/.vim/pack/themes/start/dracula

# Create folders that might be missing
mkdir -p ~/.config/fish
mkdir -p ~/.config/fish/functions
mkdir -p ~/.claude

# Link files from the repo to the HOME dir
ln -sv ~/.dotfiles/git/.gitconfig ~
ln -sv ~/.dotfiles/git/.gitconfig.unix ~
ln -sv ~/.dotfiles/git/.gitconfig.wsl ~
ln -sv ~/.dotfiles/git/.gitconfig.redgate ~
ln -sv ~/.dotfiles/fish/config.fish ~/.config/fish/
ln -sv ~/.dotfiles/fish/git.fish ~/.config/fish/functions
ln -sv ~/.dotfiles/starship/starship.toml ~/.config/
ln -sv ~/.dotfiles/tmux/.tmux.conf ~
ln -sv ~/.dotfiles/vim/.vimrc ~
ln -sv ~/.dotfiles/claude/skills ~/.claude/skills
ln -sv ~/.dotfiles/claude/hooks ~/.claude/hooks
ln -sv ~/.dotfiles/claude/statusline ~/.claude/statusline
ln -sv ~/.dotfiles/claude/agents ~/.claude/agents
ln -sv ~/.dotfiles/claude/scripts ~/.claude/scripts
ln -sv ~/.dotfiles/claude/settings.json ~/.claude/settings.json

# Restart Shell
exec fish

