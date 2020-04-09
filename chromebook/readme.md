## How to setup a fresh install of Linux on Chromebook
### Update everything
```
sudo apt update
sudo apt upgrade
sudo passwd <Username>
```

### Configure git

```
sudo apt-get install nano
ssh-keygen -t rsa -C "<email>"
sudo nano ~/.ssh/config
```

- Add the following to the empty file

```
Host github.com
 Hostname ssh.github.com
 Port 443
```

### Install the basics for shell (Tilix, ZSH and OhMyZsh)

```
git clone git@github.com:TheEadie/.dotfiles.git

sudo apt-get install tilix
sudo apt-get install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

cd ~/.dotfiles
./install.sh
cd ~/.dotfiles/tilix
./setup.sh
exec zsh
```

TODO: Automate this as part of setup.sh for tilix
 - Download the fonts from https://github.com/romkatv/powerlevel10k
 - Copy them to the linux files
 - Install the fonts

```
sudo ls /usr/local/share/fonts/
fc-cache -v
```

### Install Wine
```
sudo apt update
sudo apt install software-properties-common
sudo dpkg --add-architecture i386
wget -qO - https://dl.winehq.org/wine-builds/winehq.key | sudo apt-key add -
wget -qO - https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_10/Release.key | sudo apt-key add -
sudo apt-add-repository 'deb https://dl.winehq.org/wine-builds/debian/ buster main'
sudo apt-add-repository 'deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_10/ ./'
sudo apt install --install-recommends winehq-staging
```

### (Side-quest: Run Worms Armaggedon)
Download the installer from GOG
```
wine <installer name>.exe
mv '~/.wine/drive_c/GOG Games/Worms Armaggedon' '~/Worms/'
cd ~/Worms
wine runas /trustlevel:0x20000 wa.exe

```
### Fix Alt-Tab in full screen apps

```
mkdir -p ~/.config/systemd/user/sommelier-x@0.service.d
echo -e '[Service]\nEnvironment="SOMMELIER_ACCELERATORS=Super_L,<Alt>tab"' > ~/.config/systemd/user/sommelier-x@0.service.d/override.conf
systemctl --user daemon-reload
systemctl --user restart sommelier-x@0.service
```