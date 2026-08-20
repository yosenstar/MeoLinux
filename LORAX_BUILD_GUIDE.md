# 使用 lorax 构建 Silverblue 发行版

## 环境准备

在 Fedora 44 上操作：

```bash
# 安装依赖
sudo dnf install -y lorax lorax-lmc-novirt xorriso squashfs-tools ostree rpm-ostree

# 创建工作目录
mkdir -p ~/my-silverblue && cd ~/my-silverblue
```

---

## 获取 ostree 仓库

```bash
# 下载 Fedora Silverblue ISO
wget https://download.fedoraproject.org/pub/fedora/linux/releases/44/Silverblue/x86_64/iso/Fedora-Silverblue-ostree-x86_64-44-1.7.iso

# 挂载 ISO
sudo mkdir -p /mnt/iso
sudo mount -o loop Fedora-Silverblue-ostree-x86_64-44-1.7.iso /mnt/iso

# 解压 install.img 获取 ostree 仓库
mkdir -p /tmp/install-extract
cd /tmp/install-extract
sudo unsquashfs /mnt/iso/images/install.img

# 复制 ostree 仓库
sudo cp -a /tmp/install-extract/usr/share/ostree/repo ~/my-silverblue/ostree-repo

# 清理
cd ~/my-silverblue
sudo umount /mnt/iso
sudo rm -rf /tmp/install-extract
sudo rm -f Fedora-Silverblue-ostree-x86_64-44-1.7.iso
```

---

## 修改 ostree 仓库

```bash
# 初始化本地仓库
sudo ostree --repo=ostree-repo init

# 查看现有提交
sudo ostree --repo=ostree-repo log fedora:fedora/44/x86_64/silverblue

# 创建自定义分支
sudo ostree --repo=ostree-repo commit \
  --branch=my-silverblue/44/x86_64 \
  --parent=fedora/44/x86_64/silverblue \
  --add-metadata-string=version=44-custom \
  --add-metadata-string=description="My Custom Silverblue"
```

---

## 创建 Kickstart 文件

创建 `my-silverblue.ks`：

```bash
#version=DEVEL
# My Custom Silverblue

# 语言和时区
lang zh_CN.UTF-8
timezone Asia/Shanghai --utc
keyboard --vckeymap=us --xlayouts='us'

# 网络
network --bootproto=dhcp --activate --onboot=yes

# 安装源 - 使用本地 ostree 仓库
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
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
%end
```

---

## 构建 ISO

### 方法一：lorax + livemedia-creator

```bash
# 使用 lorax 构建安装树
sudo lorax \
  --product="My Silverblue" \
  --version="44" \
  --release="44" \
  --source="file:///etc/yum.repos.d/fedora.repo" \
  --isfinal \
  --buildarch=x86_64 \
  --nomacboot \
  build/lorax

# 将 ostree 仓库复制到安装树
sudo cp -a ostree-repo build/lorax/images/

# 使用 livemedia-creator 构建 ISO
sudo livemedia-creator \
  --ks my-silverblue.ks \
  --no-virt \
  --resultdir build/lmc \
  --project "My Silverblue" \
  --releasever 44 \
  --make-iso \
  --iso-name MySilverblue-44-x86_64.iso
```

### 方法二：直接使用 lorax

```bash
# 构建 ISO
sudo lorax \
  --product="My Silverblue" \
  --version="44" \
  --release="44" \
  --source="file:///etc/yum.repos.d/fedora.repo" \
  --isfinal \
  --buildarch=x86_64 \
  --nomacboot \
  --add-template custom-grub.tmpl \
  build/lorax

# 将 ostree 仓库和 kickstart 复制到 ISO
sudo mkdir -p build/lorax/images/ostree-repo
sudo cp -a ostree-repo/* build/lorax/images/ostree-repo/
sudo cp my-silverblue.ks build/lorax/

# 创建 ISO
sudo genisoimage -o MySilverblue-44-x86_64.iso \
  -b images/install.img \
  -c images/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e images/efiboot.img \
  -no-emul-boot \
  build/lorax
```

---

## 自定义安装器

### 修改产品名称

```bash
# 创建产品标识文件
mkdir -p product/usr/share/anaconda

cat > product/usr/share/anaconda/.buildstamp << 'EOF'
# Anaconda installer buildstamp file
utc=True
lang=en_US.UTF-8
keyboard=us
Product=My Silverblue
Base Product=Fedora
EOF

# 创建 product.img
mksquashfs product product.img -comp xz
rm -rf product

# 复制到安装树
sudo cp product.img build/lorax/images/
```

### 修改 GRUB 菜单

创建 `custom-grub.tmpl`：

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

---

## 测试 ISO

```bash
# 使用 QEMU 测试
qemu-system-x86_64 \
  -m 4096 \
  -smp 2 \
  -cdrom build/lmc/MySilverblue-44-x86_64.iso \
  -boot d \
  -enable-kvm

# 写入 U 盘测试
sudo dd if=build/lmc/MySilverblue-44-x86_64.iso of=/dev/sdX bs=4M status=progress
sync
```

---

## 常见问题

### Q: lorax 报错找不到包
A: 确保 Fedora 源已配置：
```bash
sudo dnf install https://download.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/Packages/f/fedora-release-44-1.noarch.rpm
```

### Q: ostree 仓库不可见
A: 检查挂载点和权限：
```bash
ls -la build/lorax/images/ostree-repo
```

### Q: 如何添加 RPM 包
A: 使用 rpm-ostree：
```bash
rpm-ostree install package-name
```

### Q: 如何修改默认壁纸
A: 在 kickstart 的 `%post` 中添加：
```bash
cp /path/to/wallpaper.png /usr/share/backgrounds/
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/wallpaper.png'
```
