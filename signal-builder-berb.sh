#!/bin/bash

## Script to compile signal-desktop from/for arm64 packaged for debian
#
## Version 1.0.2
#
# Upstream-Name: signal-desktop-builder
# Source: https://github.com/berbascum/signal-desktop-builder
#
# Copyright (C) 2024 Berbascum <berbascum@ticv.cat>
# All rights reserved.
#
# BSD 3-Clause License


## References:
# https://andreafortuna.org/2019/03/27/how-to-build-signal-desktop-on-linux/
# https://gitlab.com/adamthiede/signal-desktop-builder/-/blob/master/patches/0001-Remove-no-sandbox-patch.patch?ref_type=heads
# https://github.com/BernardoGiordano/signal-desktop-pi4/blob/master/install.sh
# https://github.com/tianon/dockerfiles/blob/master/signal-desktop/Dockerfile
## Flatpak
# https://github.com/signalflatpak/signal


VERSION_TO_BUILD='7.31.0'

## System Tray
#apt-get install gnome-shell-extension-appindicator

## Build depends
apt-get update && apt-get upgrade -y
apt-get install rsync build-essential libssl-dev curl git git-lfs wget vim fuse-overlayfs python3-full locales dialog libcrypto++-dev libcrypto++8 libgtk-3-0 libgtk-3-dev libvips42 libxss-dev snapd bc screen libffi-dev libglib2.0-0 libnss3 libatk1.0-0 libatk-bridge2.0-0 libx11-xcb1 libgdk-pixbuf-2.0-0 libdrm2 libgbm1 ruby ruby-dev clang llvm lld clang-tools generate-ninja ninja-build pkg-config tcl

## Runtime depends # Got using dpkg -I on a compiled
## libnotify4 libxtst6 libnss3 libasound2 libxss1 libc6>= 2.31 libgtk-3-0 libgbm1 libx11-xcb1 libappindicator3-1

# Optional:
# apt install flatpak elfutils slirp4netns rootlesskit flatpak-builder

## Install fpm is required to avoud errors on yanr install
gem install fpm
export USE_SYSTEM_FPM=true ## Should be defined for yarn build
## set PATH
export PATH="/Signal-Desktop/node_modules/.bin:/root/.cargo/bin:/opt/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

## Install nvm
curl -o- https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
## Load nvm vars
source /root/.bashrc ##required or session restart

## Clone signal desktop
[ -d "Signal-Desktop" ] || git clone https://github.com/signalapp/Signal-Desktop.git
## Grant accés to root
git config --global --add safe.directory /buildd/sources/Signal-Desktop
## Enter to the source dir
cd Signal-Desktop
## Checkout to the version to build
curr_branch=$(git branch | grep ${VERSION_TO_BUILD})
[ -z "${curr_branch}" ] && git checkout -b build-${VERSION_TO_BUILD} v${VERSION_TO_BUILD}

## Enable git lfs
git-lfs install

## Config sources
#git config --global user.name <user>
#git config --global user.email <email>

## Replace the notification sound file
cp -v ../sounds/notification.ogg sounds/notification.ogg
cp -v ../sounds/notification.ogg sounds/notification_simple-01.ogg
## Apply small screens patches
git apply ../patches/droidian/7310-01_Fix-Minimize-gutter-on-small-screens.patch
git apply ../patches/droidian/7310-03_Fix-settings-window-size-small-screens.patch
git apply ../patches/droidian/7310-02_Fix-Always-return-MIN_WIDTH-from-storage.patch

## Prepare nvm
nvm use
nvm install
nvm use

## Install yarn
npm install --global yarn
#NO npm install node-abi@latest

## Ensure required vars export
export PATH="/Signal-Desktop/node_modules/.bin:/root/.cargo/bin:/opt/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export USE_SYSTEM_FPM=true

## Check detected patches with version mismatch
## Module socks-proxy-agent
module_name='socks-proxy-agent'
mod_expected_ver="$(ls patches | grep "${module_name}" | awk -F '+' '{print $2}' | awk -F'.patch' '{print $1}')"
patch_filename="${module_name}+${mod_expected_ver}.patch"
mod_installed_ver="$(npm list -g ${module_name} | grep "${module_name}@" | awk -F'@' '{print $2}')"
if [[ "${mod_expected_ver}" == '8.0.1' \
   && "${mod_installed_ver}" == '8.0.4' ]]; then
    read -p "Detected incompatible patch v${mod_expected_ver} with installed v${mod_installed_ver}"
    rm -vf patches/${patch_filename}
fi

## Install yarn
yarn install --frozen-lockfile
## Disable --no-sandbox on the desktop link and enable Wayland compat
sed -i 's/^                exec += \" --no-sandbox %U\";/                exec += " --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations %U";/g' node_modules/app-builder-lib/out/targets/LinuxTargetHelper.js 

## Build
yarn generate
yarn build
