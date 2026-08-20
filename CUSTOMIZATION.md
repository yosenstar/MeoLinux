# MeoLinux 自定义指南

## 构建方式说明

当前使用 `build-container-installer` 从 OCI 容器镜像构建 ISO，**不使用 kickstart 文件**。

- `kickstart/meolinux.ks` - 仅作参考，不影响构建
- `.github/workflows/build.yml` - 主要构建配置
- `lorax_templates/` - 自定义 GRUB 菜单等

---

## 1. 修改系统名称

### GRUB 菜单名称
编辑 `lorax_templates/meolinux-grub.tmpl`，修改菜单条目名称：

```
menuentry 'MeoLinux 44' ...
```

### ISO 文件名
编辑 `.github/workflows/build.yml` 中的 `iso_name`：

```yaml
iso_name: MeoLinux-44-x86_64.iso
```

---

## 2. 添加 Flatpak 应用

### 方法一：在 build.yml 中添加
编辑 `.github/workflows/build.yml`，在 `flatpak_remote_refs` 中添加应用 ID：

```yaml
flatpak_remote_refs: "io.github.kolunmi.Bazaar org.mozilla.firefox com.visualstudio.code"
```

常用 Flatpak 应用 ID：
- Firefox: `org.mozilla.firefox`
- VS Code: `com.visualstudio.code`
- Steam: `com.valve.Steam`
- Discord: `com.discordapp.Discord`
- GIMP: `org.gimp.GIMP`
- VLC: `org.videolan.VLC`

### 方法二：创建应用列表文件
1. 在 `flatpak_refs/` 目录创建文件，如 `desktop.flatpak`
2. 每行一个应用 ID：
```
io.github.kolunmi.Bazaar
org.mozilla.firefox
com.visualstudio.code
```
3. 在 build.yml 中引用：
```yaml
flatpak_remote_refs_dir: "flatpak_refs"
```

---

## 3. 修改 Flatpak 仓库

```yaml
flatpak_remote_name: "flathub"
flatpak_remote_url: "https://flathub.org/repo/flathub.flatpakrepo"
```

---

## 4. 修改基础镜像

```yaml
image_name: silverblue          # 镜像名称
image_repo: quay.io/fedora-ostree-desktops  # 仓库地址
image_tag: "44"                 # 版本标签
variant: silverblue             # 变体
```

其他可选变体：
- `kinoite` - KDE Plasma 版本
- `sericea` - Sway 版本
- `onyx` - Hyprland 版本

---

## 5. 自定义 GRUB 菜单

编辑 `lorax_templates/meolinux-grub.tmpl`：

```bash
# 修改菜单标题
menuentry 'MeoLinux 44' --class fedora ...

# 添加启动参数
linux /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=MeoLinux-44-x86_64 ro quiet
```

---

## 6. 修改安装器设置

### 分区方案
需要通过 Anaconda 的 kickstart 机制，目前 `build-container-installer` 使用默认分区。

### 用户设置
安装器会提示创建用户，不需要在构建时配置。

---

## 7. 添加 RPM 包（高级）

由于使用 ostree，不能直接添加 RPM 包。需要：

1. 创建自定义 ostree 提交
2. 或使用 `rpm-ostree install` 在安装后添加

---

## 构建流程

1. 修改配置文件
2. 推送到 GitHub
3. GitHub Actions 自动构建
4. 在 Actions → Artifacts 下载 ISO

---

## 常见问题

### Q: kickstart 文件有什么用？
A: 当前构建方式不使用 kickstart，仅作参考。

### Q: 如何添加中文输入法？
A: 在 `flatpak_remote_refs` 添加：
```
com.github.f300ily.fcitx5-skin-dark
org.fcitx.Fcitx5
```

### Q: 如何修改默认壁纸？
A: 需要创建自定义容器镜像，或在安装后手动替换。

### Q: 如何添加开机自启脚本？
A: 需要创建自定义 ostree 提交，或使用 systemd 用户服务。
