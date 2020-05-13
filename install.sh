# Install ZSH
sudo apt-get install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

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

# Restart ZSH
exec zsh

