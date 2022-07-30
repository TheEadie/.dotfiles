# Install Fish 
brew install fish

# Clean up
rm ~/.gitconfig
rm ~/.gitconfig.unix
rm ~/.gitconfig.redgate
rm ~/.config/fish/config.fish

# Link files from the repo to the HOME dir
ln -sv ~/.dotfiles/git/.gitconfig ~
ln -sv ~/.dotfiles/git/.gitconfig.unix ~
ln -sv ~/.dotfiles/git/.gitconfig.redgate ~
ln -sv ~/.dotfiles/fish/config.fish ~/.config/fish/

# Restart Shell
exec fish

