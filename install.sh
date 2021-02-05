# Install ZSH
sudo apt-get install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
git clone https://github.com/romkatv/zsh-defer.git ~/.zsh-defer

# Clean up
rm ~/.zshrc
rm ~/.p10k.zsh
rm ~/.gitconfig
rm ~/.gitconfig.unix
rm ~/.gitconfig.wsl
rm ~/.gitconfig.windows

# Link files from the repo to the HOME dir
ln -sv ~/.dotfiles/zsh/.zshrc ~
ln -sv ~/.dotfiles/zsh/.p10k.zsh ~
ln -sv ~/.dotfiles/git/.gitconfig ~
ln -sv ~/.dotfiles/git/.gitconfig.unix ~
ln -sv ~/.dotfiles/git/.gitconfig.wsl ~
ln -sv ~/.dotfiles/git/.gitconfig.windows ~

# Restart ZSH
exec zsh

