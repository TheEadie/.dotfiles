# Clean up
rm ~/.zshrc
rm ~/.p10k.zsh
rm ~/.gitconfig
rm ~/.gitconfig.unix

# Link files from the repo to the HOME dir
ln -sv ~/.dotfiles/zsh/.zshrc ~
ln -sv ~/.dotfiles/zsh/.p10k.zsh ~
ln -sv ~/.dotfiles/git/.gitconfig ~
ln -sv ~/.dotfiles/git/.gitconfig.unix ~
