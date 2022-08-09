# Install tools
brew install exa
brew install gh
brew install bat
brew install dust
brew install tmux
brew install git-delta


# Install TMUX plugins
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Install Fish plugins
curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
fisher install dracula/fish
