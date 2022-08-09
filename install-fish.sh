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

# Link files from the repo to the HOME dir
ln -sv ~/.dotfiles/git/.gitconfig ~
ln -sv ~/.dotfiles/git/.gitconfig.unix ~
ln -sv ~/.dotfiles/git/.gitconfig.wsl ~
ln -sv ~/.dotfiles/git/.gitconfig.redgate ~
ln -sv ~/.dotfiles/fish/config.fish ~/.config/fish/
ln -sv ~/.dotfiles/starship/starship.toml ~/.config/
ln -sv ~/.dotfiles/tmux/.tmux.conf ~

# Restart Shell
exec fish

