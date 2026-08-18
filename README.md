# MeoLinux

一个基于 Fedora Silverblue 的 Linux 发行版，专为中国用户打造的日常桌面系统。

## 特性

- 基于 Fedora Silverblue (rpm-ostree)，系统稳定可靠
- 中文本地化支持（字体、输入法、国内镜像源）
- 预装常用日常桌面软件
- 不可变系统基础 + Flatpak 应用生态
- 自动化构建，持续更新

## 构建

### 环境要求

- Linux 系统（推荐 Fedora）
- `lorax` / `livemedia-creator` 用于构建 ISO
- 网络连接

### 手动构建

```bash
# 使用 kickstart 文件构建 ISO
livemedia-creator --make-iso \
  --ks kickstart/meolinux.ks \
  --no-virt \
  --resultdir ./build/ \
  --project "MeoLinux" \
  --releasever 44
```

### 自动构建

项目使用 GitHub Actions 自动构建 ISO 镜像。每次推送到 `main` 分支或创建 Tag 时自动触发构建。

## 项目结构

```
MeoLinux/
├── kickstart/              # Kickstart 安装配置
│   └── meolinux.ks        # 主 kickstart 文件
├── .github/
│   └── workflows/
│       └── build.yml       # CI/CD 构建流程
├── LICENSE                  # GPLv3
└── README.md
```

## 许可证

本项目基于 [GNU General Public License v3.0](LICENSE) 许可证。
