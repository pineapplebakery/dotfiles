#!/bin/bash

if [[ $(uname) == Darwin ]]; then
  echo "Can not execute on Mac OS!"
  exit 1
elif [[ $(uname) == Windows ]]; then
  echo "Can not execute on Windows!"
  exit 1
fi

if [[ -f ~/AppImage/nvim.appimage ]]; then
  rm ~/AppImage/nvim.appimage
fi

cd ~/AppImage
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
chmod u+x nvim.appimage
sudo mv ~/AppImage/nvim.appimage /usr/local/bin/nvim

