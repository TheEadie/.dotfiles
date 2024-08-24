## How to setup a fresh install of Linux on Chromebook
### Update everything
```
sudo apt update
sudo apt upgrade
sudo passwd <Username>
```

### Configure git

```
ssh-keygen -t ed25519 -C "<email>"
cat ~/.ssh/id_ed25519.pub
```

Copy the public key and upload it to GitHub

### Install the basics for shell

```
git clone git@github.com:TheEadie/.dotfiles.git

cd ~/.dotfiles
./install-fish.sh
```

It will fail the first time after `brew` is installed. Run the provided command to add brew to the PATH and then run again

```
./install-fish.sh
```

TODO: Automate this as part of a script for chromeos terminal
 - Download the fonts from https://github.com/romkatv/powerlevel10k
 - Copy them to the linux files
 - Install the fonts

```
sudo ls /usr/local/share/fonts/
fc-cache -v
```

### Fix Alt-Tab in full screen apps

```
mkdir -p ~/.config/systemd/user/sommelier-x@0.service.d
echo -e '[Service]\nEnvironment="SOMMELIER_ACCELERATORS=Super_L,<Alt>tab"' > ~/.config/systemd/user/sommelier-x@0.service.d/override.conf
systemctl --user daemon-reload
systemctl --user restart sommelier-x@0.service
```

### (Side-quest: Install Wine)
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
