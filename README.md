# 🌌 Astrea-OS

Welcome to **Astrea-OS**, a modern, minimalist, and highly customizable Linux setup based on Arch Linux and Hyprland.

## ✨ Features
- **Window Manager**: Hyprland (Wayland)
- **Shell**: Custom Shell built with [Quickshell](https://github.com/outfoxxed/quickshell)
- **Launcher**: Rofi (Wayland)
- **System Settings**: Integrated Astrea Settings app
- **Design**: Premium aesthetics with a focus on usability and micro-animations.

## 📁 Repository Structure
The repository is organized to reflect the Linux file system hierarchy:

- `.config/` : User configuration files (Hyprland, Kitty, Rofi, etc.)
- `.local/` : Core application data and settings.
- `opt/` : System applications and secondary scripts.
- `system/` : System-wide configs (SDDM themes, systemd services).
- `scripts/` : Helper scripts for installation and maintenance.

## 🚀 Installation

To install the dotfiles and dependencies, run the following command in your terminal:

```bash
git clone https://github.com/aritsuyu/Astrea-OS.git
cd Astrea-OS
bash install.sh
```

> [!IMPORTANT]
> This script uses `sudo` for system-wide changes and expects an Arch-based system with `pacman` and `yay`.

## 🛠 Software Included
Check the `softwares` file for a full list of included packages.

---
*Created with ❤️ by aritsuyu*
