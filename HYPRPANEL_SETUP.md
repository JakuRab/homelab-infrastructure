# HyprPanel Setup Guide for OpenSUSE Tumbleweed

## Overview

This guide will help you install HyprPanel with the beautiful Gruvbox theme on your OpenSUSE system. HyprPanel is built on **Astal** (the modern replacement for AGS), which we'll build from source.

## Why Your Previous Attempt Failed

1. **Broken AGS package**: OpenSUSE's `aylurs-gtk-shell` (v1.8.2) is incompatible with modern GJS (v1.86.0)
2. **Wrong framework**: HyprPanel now uses **Astal**, not the old AGS
3. **Missing dependencies**: dart-sass and Astal libraries weren't installed

## What We're Installing

- **Astal**: Modern framework for building Wayland widgets (replaces AGS v1)
  - Core libraries: astal-io, astal3, astal4
  - Service libraries: network, bluetooth, battery, hyprland, mpris, etc.
- **HyprPanel**: The actual status bar built on Astal
- **dart-sass**: Required for compiling HyprPanel's stylesheets
- **NerdFonts**: JetBrainsMono for proper icon display

## Prerequisites (Already Installed ✓)

Your system already has:
- Vala compiler (0.56.18)
- GObject Introspection
- GTK3 and GTK4 layer shells
- Meson and Ninja build tools
- npm (for dart-sass)

## Installation Steps

### Step 1: Run the Installation Script

I've created a comprehensive installation script at:
```
/home/kuba/aiTools/install_hyprpanel.sh
```

Run it with:
```bash
cd /home/kuba/aiTools
./install_hyprpanel.sh
```

**What the script does:**
1. Installs missing dependencies (dart-sass)
2. Clones Astal repository
3. Builds and installs Astal core libraries (io, gtk3, gtk4)
4. Builds and installs Astal service libraries (network, bluetooth, battery, etc.)
5. Clones and builds HyprPanel
6. Installs HyprPanel fonts

**Estimated time:** 5-10 minutes (depending on your CPU)

### Step 2: Test HyprPanel

After installation completes:

```bash
# Stop waybar first
killall waybar

# Launch HyprPanel
hyprpanel
```

You should see HyprPanel appear on your screen!

### Step 3: Configure Hyprland

If HyprPanel works, update your Hyprland config to use it permanently:

Edit: `/home/kuba/aiTools/linux/configs/hyprland/hyprland.conf`

**Change line 51 from:**
```
exec-once = swaync & hypridle & waybar
```

**To:**
```
exec-once = hypridle & hyprpanel
```

**Important notes:**
- Remove `swaync` - HyprPanel has its own notification system (conflicts!)
- Remove `waybar` - replaced by HyprPanel
- Keep `hypridle` - it's your idle/lock manager

Then sync the config:
```bash
rsync -av /home/kuba/aiTools/linux/configs/hyprland/ ~/.config/hypr/
hyprctl reload
```

### Step 4: Apply Gruvbox Theme

Once HyprPanel is running:

1. **Open HyprPanel settings** (usually by clicking on the bar or through a keyboard shortcut)
2. **Navigate to Themes** section
3. **Select "Gruvbox"** from the theme dropdown
4. The theme should apply immediately!

Alternatively, HyprPanel's theme can be configured in:
```
~/.config/hyprpanel/config.json
```

## Troubleshooting

### "command not found: hyprpanel"

The binary might not be in your PATH. Try:
```bash
sudo ldconfig  # Update library cache
hash -r        # Clear bash command cache
```

Or run directly:
```bash
/usr/bin/hyprpanel
```

### "Failed to load Astal libraries"

Make sure all Astal libraries are installed:
```bash
ldconfig -p | grep astal
```

You should see: astal-io, astal-auth, astal-battery, astal-bluetooth, etc.

### Icons not showing

The fonts might not be installed. Run:
```bash
cd /tmp/hyprpanel-build/HyprPanel
./scripts/install_fonts.sh
```

Then restart HyprPanel.

### HyprPanel crashes on start

Check logs:
```bash
journalctl --user -xeu hyprpanel
```

Or run in debug mode:
```bash
G_MESSAGES_DEBUG=all hyprpanel
```

### Theme not applying

HyprPanel stores its config in `~/.config/hyprpanel/`. Try:
```bash
# Backup and reset config
mv ~/.config/hyprpanel ~/.config/hyprpanel.bak
hyprpanel
```

## Important Files

- **Installation script**: `/home/kuba/aiTools/install_hyprpanel.sh`
- **Hyprland config**: `/home/kuba/aiTools/linux/configs/hyprland/hyprland.conf`
- **Build directory**: `/tmp/hyprpanel-build` (can be deleted after successful install)
- **HyprPanel config**: `~/.config/hyprpanel/` (created on first run)

## Useful Commands

```bash
# Check if HyprPanel is running
pgrep hyprpanel

# Stop HyprPanel
killall hyprpanel

# Restart HyprPanel
killall hyprpanel && hyprpanel &

# View HyprPanel version/info
hyprpanel --version

# Check installed Astal libraries
ls -la /usr/lib*/libastal*
```

## Next Steps After Installation

1. **Customize the bar**: HyprPanel has extensive configuration options
2. **Set up widgets**: Enable/disable modules you want (battery, network, CPU, etc.)
3. **Adjust positioning**: Configure bar position, size, and spacing
4. **Explore themes**: Try other color schemes besides Gruvbox
5. **Configure shortcuts**: Set up keybindings for HyprPanel controls

## Resources

- **HyprPanel Wiki**: https://hyprpanel.com/
- **Astal Documentation**: https://aylur.github.io/astal/
- **HyprPanel GitHub**: https://github.com/Jas-SinghFSU/HyprPanel
- **Astal GitHub**: https://github.com/Aylur/astal

## Cleanup

After confirming everything works, you can remove the build directory:
```bash
rm -rf /tmp/hyprpanel-build
```

---

**Good luck with your HyprPanel setup! Enjoy that beautiful Gruvbox theme! 🚀**
