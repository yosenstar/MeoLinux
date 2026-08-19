#version=DEVEL
# MeoLinux Kickstart 文件
# 基于 Fedora Silverblue 44，专为中国桌面用户打造

# 键盘布局
keyboard --vckeymap=us --xlayouts='us'

# 系统语言 - 中文简体
lang zh_CN.UTF-8

# 系统时区 - 中国标准时间
timezone Asia/Shanghai --utc

# 网络配置 - DHCP 自动获取
network --bootproto=dhcp --activate --onboot=yes

# SELinux 安全策略
selinux --enforcing

# 防火墙 - 启用
firewall --enabled --service=mdns

# OSTree 设置 - Fedora Silverblue 44
# 从安装介质中的 ostree 仓库安装基础系统
ostreesetup --nogpg --osname="fedora" --remote="fedora" --url="file:///workspace/ostree-repo" --ref="fedora/44/x86_64/silverblue"

# 磁盘分区方案
# EFI 分区 + 引导分区 + 根分区 + 家目录分区
zerombr
clearpart --all --initlabel
part /boot/efi --fstype=fat32 --size=600 --ondisk=sda
part /boot --fstype=xfs --size=1024 --ondisk=sda
part / --fstype=xfs --size=20480 --grow --ondisk=sda
part /home --fstype=xfs --size=10240 --ondisk=sda

# Root 密码（Live 镜像使用简单密码，用户首次启动可修改）
rootpw --plaintext meolinux

# 创建默认用户 meo，加入 wheel 组（有 sudo 权限）
user --name=meo --groups=wheel --plaintext --password=meolinux

# 跳过交互式设置
skipx

# 禁用首次启动向导
firstboot --disable

# 安装完成后重启
reboot

# 安装基础系统包
%packages
dracut-live
dracut-network
@core
@base-x
%end

# ---- 安装后配置脚本 ----

# 基础配置（无需网络）
%post --erroronfail --log=/root/meolinux-post.log
#!/bin/bash
set -ex

# 设置默认语言环境
cat > /etc/profile.d/meolinux.sh << 'EOF'
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
EOF

# 为新用户配置默认环境
cat > /etc/skel/.bashrc << 'EOF'
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
EOF

# 设置时区
timedatectl set-timezone Asia/Shanghai

# 创建首次启动配置脚本
cat > /usr/local/bin/meolinux-firstboot.sh << 'FIRSTBOOT'
#!/bin/bash
# MeoLinux 首次启动配置脚本

echo "=== MeoLinux 首次启动配置 ==="

# 启用 RPM Fusion 源
rpm-ostree install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm || true

# 安装中文字体
rpm-ostree install -y \
  google-noto-sans-cjk-fonts \
  google-noto-serif-cjk-fonts \
  wqy-microhei-fonts || true

# 安装多媒体包
rpm-ostree install -y \
  ffmpeg \
  gstreamer1-plugins-good || true

# 安装中文输入法
rpm-ostree install -y \
  ibus-libpinyin || true

# 添加 Flathub
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

# 安装常用 Flatpak 应用
flatpak install -y --user flathub \
  org.mozilla.firefox \
  org.libreoffice.LibreOffice \
  org.videolan.VLC || true

echo "=== 配置完成，请重启系统 ==="
FIRSTBOOT
chmod +x /usr/local/bin/meolinux-firstboot.sh

# 添加到 systemd 首次启动服务
cat > /etc/systemd/system/meolinux-firstboot.service << 'SERVICE'
[Unit]
Description=MeoLinux First Boot Configuration
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/meolinux-firstboot-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/meolinux-firstboot.sh
ExecStartPost=/bin/touch /var/lib/meolinux-firstboot-done
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

systemctl enable meolinux-firstboot.service 2>/dev/null || true

echo "MeoLinux 安装后配置完成"
%end
