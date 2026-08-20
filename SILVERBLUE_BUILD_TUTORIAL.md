# 构建基于 Fedora Silverblue 的自定义发行版教程

从零开始构建一个基于 Fedora Silverblue 的自定义 Linux 发行版。

---

## 目录

1. [理解 Silverblue 架构](#1-理解-silverblue-架构)
2. [准备开发环境](#2-准备开发环境)
3. [创建自定义 ostree 提交](#3-创建自定义-ostree-提交)
4. [构建安装 ISO](#4-构建安装-iso)
5. [自定义系统](#5-自定义系统)
6. [发布和维护](#6-发布和维护)

---

## 1. 理解 Silverblue 架构

### 什么是 Silverblue？
- **不可变操作系统**：系统文件只读，不能直接修改
- **原子更新**：更新要么完全成功，要么完全回滚
- **Flatpak 应用**：应用沙盒化，独立于系统
- **ostree**：版本控制系统，管理文件系统快照

### 核心组件
```
┌─────────────────────────────────────┐
│           用户空间应用              │
│  (Flatpak / Distrobox / Toolbox)    │
├─────────────────────────────────────┤
│         rpm-ostree 层              │
│   (添加 RPM 包到基础系统)          │
├─────────────────────────────────────┤
│         ostree 基础系统            │
│   (Fedora Silverblue 核心)         │
├─────────────────────────────────────┤
│           Linux 内核               │
└─────────────────────────────────────┘
```

### 关键概念
- **ostree commit**：系统的版本快照
- **rpm-ostree**：在 ostree 基础上添加 RPM 包
- **Flatpak**：用户空间应用
- **Distrobox/Toolbox**：开发容器

---

## 2. 准备开发环境

### 2.1 安装 Fedora Silverblue
```bash
# 下载 Fedora Silverblue 44
https://download.fedoraproject.org/pub/fedora/linux/releases/44/Silverblue/x86_64/iso/

# 安装到虚拟机或物理机
```

### 2.2 安装开发工具
```bash
# 安装必要工具
sudo rpm-ostree install \
  git \
  podman \
  rpm-ostree \
  composefs \
  ostree \
  lorax \
  lorax-lmc-novirt \
  xorriso \
  squashfs-tools

# 重启系统
sudo reboot
```

### 2.3 配置开发环境
```bash
# 创建开发目录
mkdir -p ~/my-silverblue
cd ~/my-silverblue

# 初始化 Git 仓库
git init
```

---

## 3. 创建自定义 ostree 提交

### 3.1 方法一：基于现有 ostree 提交修改

#### 3.1.1 获取基础 ostree 提交
```bash
# 查看当前 ostree 提交
ostree log fedora:fedora/44/x86_64/silverblue

# 或者从容器镜像导入
sudo ostree pull remote=oci --repo=/path/to/repo \
  docker://quay.io/fedora-ostree-desktops/silverblue:44
```

#### 3.1.2 创建自定义分支
```bash
# 创建新的分支
sudo ostree commit \
  --repo=/path/to/repo \
  --branch=my-silverblue/44/x86_64 \
  --parent=fedora/44/x86_64/silverblue \
  --add-metadata-string=version=44-custom \
  --add-metadata-string=description="My Custom Silverblue"
```

### 3.2 方法二：使用 rpm-ostree 构建

#### 3.2.1 创建 rpm-ostree 配置
```bash
# 创建配置目录
mkdir -p my-image
cd my-image
```

创建 `image.yaml`：
```yaml
name: my-silverblue
description: My Custom Silverblue Distribution
baseimage: fedora-silverblue
releasever: 44
```

创建 `packages.yaml`：
```yaml
packages:
  - firefox
  - gnome-terminal
  - git
  - vim
  - htop

remove-packages:
  - firefox
```

#### 3.2.2 构建自定义镜像
```bash
# 使用 podman 构建
sudo podman build \
  --tag my-silverblue:latest \
  --file Containerfile .
```

### 3.3 方法三：使用 ForgeIgnite（推荐）

#### 3.3.1 安装 ForgeIgnite
```bash
# 安装 ForgeIgnite
pip install forgeigniter
```

#### 3.3.2 创建 Forge 配置
```bash
# 创建 Forge 配置
forge init my-image
cd my-image
```

编辑 `image.yaml`：
```yaml
name: my-silverblue
baseimage: fedora
release: 44
variant: silverblue

packages:
  add:
    - firefox
    - gnome-terminal
    - git
    - vim
    
  remove:
    - firefox
```

#### 3.3.3 构建镜像
```bash
# 构建 ostree 镜像
forge build

# 导出为 OCI 镜像
forge export
```

---

## 4. 构建安装 ISO

### 4.1 方法一：使用 lorax + livemedia-creator

#### 4.1.1 准备 ostree 仓库
```bash
# 创建本地 ostree 仓库
sudo mkdir -p /srv/ostree-repo
sudo ostree --repo=/srv/ostree-repo init --mode=archive-z2

# 导入自定义 ostree 提交
sudo ostree --repo=/srv/ostree-repo pull-local \
  /path/to/your/repo \
  my-silverblue/44/x86_64
```

#### 4.1.2 创建 kickstart 文件
创建 `my-image.ks`：
```bash
#version=DEVEL
# My Custom Silverblue Kickstart

# 语言和时区
lang zh_CN.UTF-8
timezone Asia/Shanghai --utc
keyboard --vckeymap=us --xlayouts='us'

# 网络
network --bootproto=dhcp --activate --onboot=yes

# 安装源
ostreesetup --nogpg \
  --osname="my-silverblue" \
  --remote="my-remote" \
  --url="file:///run/install/repo" \
  --ref="my-silverblue/44/x86_64"

# 分区
zerombr
clearpart --all --initlabel
part /boot/efi --fstype=fat32 --size=600 --ondisk=sda
part /boot --fstype=xfs --size=1024 --ondisk=sda
part / --fstype=xfs --size=20480 --grow --ondisk=sda

# 用户
rootpw --plaintext password
user --name=user --groups=wheel --plaintext --password=password

# 首次启动
firstboot --disable
reboot

# 包
%packages
dracut-live
@core
@base-x
@gnome-desktop
%end

# 安装后配置
%post
#!/bin/bash
# 添加 Flathub
flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
%end
```

#### 4.1.3 构建 ISO
```bash
# 方法 A：使用 lorax
sudo lorax \
  --product="My Silverblue" \
  --version="44" \
  --release="44" \
  --source="file:///etc/yum.repos.d/fedora.repo" \
  --isfinal \
  --buildarch=x86_64 \
  --nomacboot \
  --add-template meolinux-grub.tmpl \
  build/lorax

# 方法 B：使用 livemedia-creator
sudo livemedia-creator \
  --ks my-image.ks \
  --no-virt \
  --resultdir build/lmc \
  --project "My Silverblue" \
  --releasever 44 \
  --make-iso \
  --iso-name MySilverblue-44-x86_64.iso \
  --macboot
```

### 4.2 方法二：使用 build-container-installer（推荐）

#### 4.2.1 创建 GitHub Actions 工作流
创建 `.github/workflows/build.yml`：
```yaml
name: Build Custom Silverblue ISO

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Build ISO
        uses: jasonn3/build-container-installer@main
        id: build
        with:
          arch: x86_64
          image_name: silverblue
          image_repo: quay.io/fedora-ostree-desktops
          image_tag: "44"
          version: "44"
          variant: silverblue
          iso_name: MySilverblue-44-x86_64.iso
          flatpak_remote_refs: "io.github.kolunmi.Bazaar org.mozilla.firefox"

      - name: Upload ISO artifact
        uses: actions/upload-artifact@v4
        with:
          name: MySilverblue-ISO
          path: |
            ${{ steps.build.outputs.iso_path }}/${{ steps.build.outputs.iso_name }}
            ${{ steps.build.outputs.iso_path }}/${{ steps.build.outputs.iso_name }}-CHECKSUM
          retention-days: 30
```

---

## 5. 自定义系统

### 5.1 自定义安装器外观

#### 5.1.1 创建产品标识
创建 `lorax_templates/product/.buildstamp`：
```ini
# Anaconda installer buildstamp file
utc=True
lang=en_US.UTF-8
keyboard=us
Product=My Silverblue
Base Product=Fedora
```

#### 5.1.2 创建品牌 CSS
创建 `lorax_templates/product/branding.css`：
```css
/* My Silverblue Branding */
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

#### 5.1.3 创建 product.img
```bash
# 创建临时目录
mkdir -p product/usr/share/anaconda
mkdir -p product/usr/share/cockpit/branding

# 复制文件
cp lorax_templates/product/.buildstamp product/usr/share/anaconda/
cp lorax_templates/product/branding.css product/usr/share/cockpit/branding/

# 创建 product.img
mksquashfs product product.img -comp xz

# 清理
rm -rf product
```

### 5.2 自定义 GRUB 菜单

创建 `lorax_templates/custom-grub.tmpl`：
```bash
# Custom GRUB menu
menuentry 'My Silverblue 44' --class fedora --class gnu-linux --class gnu --class os {
    linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=MySilverblue-44-x86_64 ro
    initrd /images/pxeboot/initrd.img
}

menuentry 'My Silverblue 44 (Basic Graphics)' --class fedora --class gnu-linux --class gnu --class os {
    linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=MySilverblue-44-x86_64 ro nomodeset
    initrd /images/pxeboot/initrd.img
}
```

### 5.3 预装 Flatpak 应用

在 kickstart 文件的 `%post` 部分添加：
```bash
%post
#!/bin/bash

# 添加 Flathub
flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo

# 安装常用应用
flatpak install -y flathub org.mozilla.firefox
flatpak install -y flathub io.github.kolunmi.Bazaar
flatpak install -y flathub com.visualstudio.code
flatpak install -y flathub com.valve.Steam
flatpak install -y flathub com.discordapp.Discord

%end
```

### 5.4 修改 GNOME 设置

在 `%post` 部分添加：
```bash
# 设置默认壁纸
cp /path/to/wallpaper.png /usr/share/backgrounds/
gsettings set org.gnome.desktop.background picture-uri \
  'file:///usr/share/backgrounds/wallpaper.png'

# 设置默认主题
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'

# 禁用自动锁屏
gsettings set org.gnome.desktop.screensaver lock-enabled false
```

---

## 6. 发布和维护

### 6.1 创建 ostree 仓库

#### 6.1.1 本地仓库
```bash
# 创建仓库
sudo mkdir -p /srv/ostree-repo
sudo ostree --repo=/srv/ostree-repo init --mode=archive-z2

# 导入提交
sudo ostree --repo=/srv/ostree-repo pull-local \
  /path/to/your/repo \
  my-silverblue/44/x86_64
```

#### 6.1.2 远程仓库
```bash
# 使用 GitHub Pages
# 1. 导出仓库
ostree --repo=/srv/ostree-repo static-delta generate my-silverblue/44/x86_64

# 2. 上传到 GitHub Pages
# 3. 配置 ostree remote
sudo ostree remote add my-remote https://username.github.io/ostree-repo
```

### 6.2 发布 ISO

#### 6.2.1 上传到 GitHub Releases
```bash
# 创建 tag
git tag -a v1.0 -m "Release 1.0"
git push origin v1.0

# GitHub Actions 会自动构建并上传 ISO
```

#### 6.2.2 上传到其他平台
- **SourceForge**: 适合大文件
- **自建服务器**: 完全控制
- **云存储**: AWS S3, Google Cloud Storage

### 6.3 更新维护

#### 6.3.1 更新基础系统
```bash
# 拉取最新的 Fedora Silverblue
sudo ostree pull remote=oci --repo=/path/to/repo \
  docker://quay.io/fedora-ostree-desktops/silverblue:44

# 创建新的自定义提交
sudo ostree commit \
  --repo=/path/to/repo \
  --branch=my-silverblue/44/x86_64 \
  --parent=fedora/44/x86_64/silverblue
```

#### 6.3.2 添加安全更新
```bash
# 检查安全更新
rpm-ostree upgrade --check

# 应用更新
rpm-ostree upgrade
```

---

## 完整示例

### 创建自定义 Silverblue 发行版

```bash
# 1. 克隆 Fedora Silverblue
git clone https://github.com/fedora-silverblue/silverblue-config
cd silverblue-config

# 2. 修改配置
# 编辑 packages.yaml 添加你的包
# 修改 image.yaml 设置你的发行版信息

# 3. 构建 ostree 提交
forge build

# 4. 导出为 OCI 镜像
forge export

# 5. 构建 ISO
sudo livemedia-creator \
  --ks my-image.ks \
  --no-virt \
  --resultdir build \
  --project "My Silverblue" \
  --releasever 44 \
  --make-iso

# 6. 测试 ISO
qemu-system-x86_64 -m 4096 -cdrom build/*.iso -boot d -enable-kvm
```

---

## 常见问题

### Q: ostree 提交失败
A: 检查仓库权限和磁盘空间：
```bash
# 检查仓库
sudo ostree --repo=/path/to/repo fsck

# 清理仓库
sudo ostree --repo=/path/to/repo prune --keep-last=5
```

### Q: ISO 构建失败
A: 检查 kickstart 文件语法：
```bash
ksvalidator my-image.ks
```

### Q: 如何添加 RPM 包
A: 使用 rpm-ostree：
```bash
rpm-ostree install package-name
rpm-ostree rebase --hotfix
```

### Q: 如何自定义内核
A: 构建自定义内核 RPM：
```bash
# 下载内核源码
koji download-build --arch=src kernel-6.8.11-300.fc40

# 修改配置并构建
rpmbuild -bb kernel.spec

# 使用 rpm-ostree 安装
rpm-ostree install ./kernel-*.rpm
```

---

## 参考资源

- [Fedora Silverblue 官方文档](https://docs.fedoraproject.org/en-US/fedora-silverblue/)
- [ostree 文档](https://ostreedev.github.io/ostree/)
- [rpm-ostree 文档](https://rpm-ostree.readthedocs.io/)
- [Flatpak 文档](https://docs.flatpak.org/)
- [Anaconda 自定义](https://anaconda-installer.readthedocs.io/)
- [ForgeIgnite](https://github.com/forgeigniter/forgeigniter)
