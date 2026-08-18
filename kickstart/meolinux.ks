#version=DEVEL
# MeoLinux Kickstart File
# Based on Fedora Silverblue 44 for Chinese desktop users

# keyboard
keyboard --vckeymap=us --xlayouts='us'

# System language
lang zh_CN.UTF-8

# System timezone
timezone Asia/Shanghai --utc

# Network configuration
network --bootproto=dhcp --activate --onboot=yes

# Root password (insecure, for live image only - user should change on first boot)
rootpw --plaintext --lock meolinux

# User creation
user --name=meo --groups=wheel --plaintext --password=meolinux

# SELinux
selinux --enforcing

# Firewall
firewall --enabled --service=mdns

# OSTree setup - Fedora Silverblue 44 (repo extracted from official ISO)
ostreesetup --nogpg --osname="fedora" --remote="fedora" --url="file:///ostree/repo" --ref="fedora/44/x86_64/silverblue"

# Disk partitioning
zerombr
clearpart --all --initlabel
part /boot/efi --fstype=fat32 --size=600 --ondisk=sda
part /boot --fstype=xfs --size=1024 --ondisk=sda
part / --fstype=xfs --size=20480 --grow --ondisk=sda
part /home --fstype=xfs --size=10240 --ondisk=sda

# Skip interactive setup
skipx

# Run the Setup Agent on first boot
firstboot --disable

# Reboot after installation
reboot

# Required packages for live ISO build
%packages
dracut-live
dracut-network
%end

# ---- Post-installation scripts ----

# Configure Chinese mirrors and repos
%post --erroronfail --log=/root/meolinux-post.log
#!/bin/bash
set -ex

# Add Chinese locale
localectl set-locale LANG=zh_CN.UTF-8

# Configure Chinese timezone
timedatectl set-timezone Asia/Shanghai

# Enable RPM Fusion repos (needed for multimedia, codecs, etc.)
rpm-ostree install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm

# Install Chinese fonts
rpm-ostree install -y \
  google-noto-sans-cjk-fonts \
  google-noto-serif-cjk-fonts \
  google-noto-sans-cjk-ttc-fonts \
  wqy-microhei-fonts \
  wqy-zenhei-fonts

# Install common multimedia packages
rpm-ostree install -y \
  ffmpeg \
  gstreamer1-plugins-good \
  gstreamer1-plugins-bad-free \
  gstreamer1-plugins-ugly-free \
  gstreamer1-libav

# Install Chinese input method
rpm-ostree install -y \
  ibus-libpinyin \
  ibus-rime

# Set default locale in profile
cat >> /etc/profile.d/meolinux.sh << 'EOF'
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
EOF

# Configure Chinese timezone for users
cat >> /etc/skel/.bashrc << 'EOF'
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
EOF

echo "MeoLinux post-install completed successfully"
%end

# Install Flatpak applications
%post --erroronfail --log=/root/meolinux-flatpak.log
#!/bin/bash
set -ex

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install common desktop applications via Flatpak
flatpak install -y --user flathub \
  org.mozilla.firefox \
  org.libreoffice.LibreOffice \
  org.gnome.Calendar \
  org.gnome.tweaks \
  org.gnome.Extensions \
  com.visualstudio.code \
  org.mozilla.firefox \
  org.gimp.GIMP \
  org.videolan.VLC \
  org.telegram.desktop \
  com.slack.Slack \
  io.github.shiftrix.Terminix \
  org.gnome.Calculator \
  org.gnome.Nautilus \
  org.gnome.TextEditor

echo "MeoLinux Flatpak installation completed"
%end
