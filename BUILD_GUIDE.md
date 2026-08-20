# MeoLinux ISO 构建指南（Fedora 本地构建）

在 Fedora 系统上手动构建 MeoLinux ISO，完全自定义系统。

---

## 一、环境准备

### 1. 安装 Fedora 44
确保你的系统是 Fedora 44 Workstation。

### 2. 安装依赖
```bash
sudo dnf install -y \
  lorax \
  lorax-lmc-novirt \
  xorriso \
  squashfs-tools \
  dosfstools \
  mtools \
  genisoimage \
  isomd5sum \
  pykickstart \
  ostree \
  rpm-ostree
```

---

## 二、获取项目文件

### 1. 克隆项目
```bash
git clone https://github.com/yosenstar/MeoLinux.git
cd MeoLinux
```

### 2. 或者手动创建目录结构
```
MeoLinux/
├── kickstart/
│   └── meolinux.ks          # Kickstart 配置文件
├── lorax_templates/          # 自定义 Lorax 模板
│   ├── meolinux-grub.tmpl
│   └── meolinux-installer.tmpl
└── build.sh                  # 构建脚本
```

---

## 三、Kickstart 文件说明

编辑 `kickstart/meolinux.ks`，这是系统安装的配置文件。

### 基础配置
```bash
# 语言
lang zh_CN.UTF-8

# 时区
timezone Asia/Shanghai --utc

# 键盘
keyboard --vckeymap=us --xlayouts='us'

# 网络
network --bootproto=dhcp --activate --onboot=yes

# SELinux
selinux --enforcing

# 防火墙
firewall --enabled --service=mdns
```

### 安装源
```bash
# 使用 Fedora 44 Everything
url --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-44&arch=$basearch
```

### 分区方案
```bash
zerombr
clearpart --all --initlabel
part /boot/efi --fstype=fat32 --size=600 --ondisk=sda
part /boot --fstype=xfs --size=1024 --ondisk=sda
part / --fstype=xfs --size=20480 --grow --ondisk=sda
part /home --fstype=xfs --size=10240 --ondisk=sda
```

### 用户配置
```bash
rootpw --plaintext meolinux
user --name=meo --groups=wheel --plaintext --password=meolinux
```

### 安装包
```bash
%packages
@core
@base-x
@gnome-desktop
@standard
firefox
flatpak
flatpak-remote-flathub
gnome-software
gnome-software-flatpak-plugin
kernel-modules-extra
%end
```

### 安装后配置
```bash
%post --interpreter=/bin/bash
#!/bin/bash

# 设置主机名
hostnamectl set-hostname meolinux

# 添加 Flathub 仓库
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# 安装 Bazaar 商店
flatpak install -y flathub io.github.kolunmi.Bazaar || true

# 禁用不必要的服务
systemctl disable bluetooth.service || true
systemctl disable cups.service || true

# 清理缓存
dnf clean all
rm -rf /var/cache/dnf/*
%end
```

---

## 四、自定义安装器外观

### 1. 创建产品标识文件
```bash
mkdir -p product
```

创建 `product/.buildstamp`：
```ini
# Anaconda installer buildstamp file
utc=True
lang=en_US.UTF-8
keyboard=us
Product=MeoLinux
Base Product=Fedora
```

### 2. 创建品牌 CSS
创建 `product/branding.css`：
```css
/* MeoLinux Branding */
.anaconda {
    --brand-default-light: #61afef;
    --brand-default: #528bff;
    --brand-default-dark: #1e90ff;
}

:not(.pf-v6-theme-dark) .anaconda {
    --pf-t--global--color--brand--default: var(--brand-default);
    --pf-t--global--color--brand--hover: var(--brand-default-dark);
}

.pf-v6-theme-dark .anaconda {
    --pf-t--global--color--brand--default: var(--brand-default-light);
    --pf-t--global--color--brand--hover: var(--brand-default);
}
```

### 3. 创建 product.img
```bash
# 创建临时目录
mkdir -p product/usr/share/anaconda
mkdir -p product/usr/share/cockpit/branding

# 复制文件
cp product/.buildstamp product/usr/share/anaconda/
cp product/branding.css product/usr/share/cockpit/branding/

# 创建 product.img
mksquashfs product product.img -comp xz

# 清理
rm -rf product
```

---

## 五、构建 ISO

### 方法一：使用 lorax + livemedia-creator
```bash
# 创建构建目录
mkdir -p build

# 使用 lorax 构建安装树
sudo lorax \
  --product="MeoLinux" \
  --version="44" \
  --release="44" \
  --source="file:///etc/yum.repos.d/fedora.repo" \
  --isfinal \
  --buildarch=x86_64 \
  --nomacboot \
  build/lorax

# 使用 livemedia-creator 构建 ISO
sudo livemedia-creator \
  --ks kickstart/meolinux.ks \
  --no-virt \
  --resultdir build/lmc \
  --project "MeoLinux" \
  --releasever 44 \
  --make-iso \
  --iso-name MeoLinux-44-x86_64.iso \
  --macboot \
  --product-img product.img
```

### 方法二：使用 lorax 模板
```bash
# 创建自定义 Lorax 模板
mkdir -p custom-templates

# 复制模板
cp lorax_templates/*.tmpl custom-templates/

# 使用自定义模板构建
sudo lorax \
  --product="MeoLinux" \
  --version="44" \
  --release="44" \
  --source="file:///etc/yum.repos.d/fedora.repo" \
  --isfinal \
  --buildarch=x86_64 \
  --add-template custom-templates/meolinux-grub.tmpl \
  --add-template custom-templates/meolinux-installer.tmpl \
  build/custom-lorax
```

---

## 六、自定义 GRUB 菜单

编辑 `lorax_templates/meolinux-grub.tmpl`：

```bash
# 修改菜单标题
menuentry 'MeoLinux 44' --class fedora --class gnu-linux --class gnu --class os {
    linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=MeoLinux-44-x86_64 ro
    initrd /images/pxeboot/initrd.img
}
```

---

## 七、添加 Flatpak 应用

在 `%packages` 之后添加：
```bash
%post --interpreter=/bin/bash
#!/bin/bash

# 安装 Flatpak 应用
flatpak install -y flathub io.github.kolunmi.Bazaar
flatpak install -y flathub org.mozilla.firefox
flatpak install -y flathub com.visualstudio.code
flatpak install -y flathub com.valve.Steam
flatpak install -y flathub com.discordapp.Discord

%end
```

---

## 八、测试 ISO

### 1. 创建虚拟机测试
```bash
# 使用 QEMU 测试
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -cdrom build/lmc/MeoLinux-44-x86_64.iso \
  -boot d \
  -enable-kvm
```

### 2. 写入 U 盘测试
```bash
# 查看 U 盘设备
lsblk

# 写入 U 盘（注意替换 /dev/sdX）
sudo dd if=build/lmc/MeoLinux-44-x86_64.iso of=/dev/sdX bs=4M status=progress
sync
```

---

## 九、常见问题

### Q: lorax 报错找不到包
A: 确保 Fedora 44 源已配置：
```bash
sudo dnf install https://download.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/Packages/f/fedora-release-44-1.noarch.rpm
```

### Q: livemedia-creator 报错
A: 检查 kickstart 文件语法：
```bash
ksvalidator kickstart/meolinux.ks
```

### Q: 如何添加中文输入法
A: 在 `%packages` 中添加：
```
ibus-libpinyin
ibus-rime
```

### Q: 如何修改默认壁纸
A: 在 `%post` 中添加：
```bash
# 复制壁纸
cp wallpaper.png /usr/share/backgrounds/

# 设置壁纸
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/wallpaper.png'
```

### Q: 如何添加开机自启脚本
A: 在 `%post` 中创建 systemd 服务：
```bash
cat > /etc/systemd/system/meolinux-startup.service << 'EOF'
[Unit]
Description=MeoLinux Startup Script
After=graphical.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/meolinux-startup.sh
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF

chmod +x /usr/local/bin/meolinux-startup.sh
systemctl enable meolinux-startup.service
```

---

## 十、完整构建流程

```bash
# 1. 安装依赖
sudo dnf install -y lorax lorax-lmc-novirt xorriso squashfs-tools

# 2. 克隆项目
git clone https://github.com/yosenstar/MeoLinux.git
cd MeoLinux

# 3. 自定义配置
vim kickstart/meolinux.ks

# 4. 构建 ISO
sudo livemedia-creator \
  --ks kickstart/meolinux.ks \
  --no-virt \
  --resultdir build \
  --project "MeoLinux" \
  --releasever 44 \
  --make-iso \
  --iso-name MeoLinux-44-x86_64.iso

# 5. 测试 ISO
qemu-system-x86_64 -m 4096 -cdrom build/MeoLinux-44-x86_64.iso -boot d -enable-kvm
```

---

## 注意事项

1. **构建时间**：首次构建需要 30-60 分钟
2. **磁盘空间**：需要至少 20GB 可用空间
3. **网络**：构建过程需要下载大量包
4. **权限**：需要 sudo 权限
5. **Fedora 版本**：建议使用 Fedora 44 进行构建
