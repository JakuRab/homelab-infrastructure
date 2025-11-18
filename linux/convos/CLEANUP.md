# HyprPanel Build Cleanup Guide

**Date:** 2025-11-16
**Purpose:** Remove all artifacts from the failed HyprPanel installation attempt

## Quick Cleanup (Copy-Paste Safe)

```bash
# 1. Remove temporary build directories
rm -rf /tmp/hyprpanel-build
rm -rf /tmp/ags
rm -rf /tmp/astal

# 2. Remove installation scripts
cd /home/kuba/aiTools
rm -f install_hyprpanel.sh
rm -f install_hyprpanel_fixed.sh
rm -f install_hyprpanel_patched.sh
rm -f install_hyprpanel_v3.sh
rm -f INSTALL_HYPRPANEL_FINAL.sh

# 3. Remove patcher tools
rm -f patch_astal_gir.py
rm -f patch_astal_simple.py
rm -f patch_astal_fixed.py
rm -f patch_astal_working.py
rm -f patch_use_vala_gir.py
rm -f manual_patch_astal.sh
rm -f simple_sed_patch.sh

# 4. Remove documentation (optional - keep for reference)
# rm -f HYPRPANEL_SETUP.md

# 5. Verify cleanup
echo "=== Cleanup verification ==="
echo "Temp dirs remaining:"
ls -d /tmp/hyprpanel-build /tmp/ags /tmp/astal 2>/dev/null || echo "  ✓ All removed"
echo "Scripts remaining:"
ls -1 /home/kuba/aiTools/*.sh 2>/dev/null | grep -E "hyprpanel|patch" || echo "  ✓ All removed"
echo "Patchers remaining:"
ls -1 /home/kuba/aiTools/*.py 2>/dev/null | grep -E "patch|astal" || echo "  ✓ All removed"
```

## Detailed Cleanup Steps

### 1. Temporary Build Directories

These directories contain cloned source code and build artifacts:

```bash
# HyprPanel source and build files (~50MB)
rm -rf /tmp/hyprpanel-build

# AGS CLI source and build files (~30MB)
rm -rf /tmp/ags

# Astal source (if cloned separately)
rm -rf /tmp/astal
```

**Verification:**
```bash
du -sh /tmp/hyprpanel-build /tmp/ags /tmp/astal 2>/dev/null
# Should return: "No such file or directory"
```

### 2. Installation Scripts (7 files)

All located in `/home/kuba/aiTools/`:

```bash
cd /home/kuba/aiTools

# Original attempt
rm -f install_hyprpanel.sh

# With -Dintrospection flag (didn't work)
rm -f install_hyprpanel_fixed.sh

# With sed patcher (broke syntax)
rm -f install_hyprpanel_patched.sh

# With better Python patcher
rm -f install_hyprpanel_v3.sh

# Final working build script (builds but won't run)
rm -f INSTALL_HYPRPANEL_FINAL.sh
```

### 3. Patcher Tools (7 files)

All located in `/home/kuba/aiTools/`:

```bash
cd /home/kuba/aiTools

# Python patchers
rm -f patch_astal_gir.py          # Regex approach
rm -f patch_astal_simple.py       # Line-by-line parser
rm -f patch_astal_fixed.py        # Lookahead detection
rm -f patch_astal_working.py      # ✓ Working two-pass patcher
rm -f patch_use_vala_gir.py       # Incomplete attempt

# Shell script patchers
rm -f manual_patch_astal.sh       # Abandoned awk approach
rm -f simple_sed_patch.sh         # Abandoned sed approach
```

### 4. Documentation Files (Optional)

**Keep for reference** unless you're certain you won't need the documentation:

```bash
# Optional: Remove setup guide
# rm -f /home/kuba/aiTools/HYPRPANEL_SETUP.md

# Keep the detailed journey documentation:
# /home/kuba/aiTools/linux/convos/HyprPanel.md
# /home/kuba/aiTools/linux/convos/CLEANUP.md (this file)
```

### 5. Installed System Packages (Optional)

These packages were installed specifically for HyprPanel. Only remove if you don't need them for other purposes:

```bash
# Remove AGS CLI (if you don't plan to use it)
sudo rm -f /usr/bin/ags
sudo rm -rf /usr/share/astal/gjs

# Remove HyprPanel binaries (non-functional)
sudo rm -f /usr/bin/hyprpanel
sudo rm -rf /usr/share/hyprpanel

# Optional: Remove dependencies installed for build
# WARNING: Only remove if nothing else needs them!
# sudo zypper remove json-glib-devel pam-devel
# sudo npm uninstall -g sass
```

**Verification:**
```bash
which ags hyprpanel
# Should return: "not found" for both

ls /usr/share/astal /usr/share/hyprpanel 2>/dev/null
# Should return: "No such file or directory"
```

### 6. Installed Astal Libraries (Optional)

The Astal C libraries were built without GIR/typelib, making them non-functional for JavaScript use. Remove if desired:

```bash
# Remove Astal core libraries
sudo rm -f /usr/lib64/libastal-io.so*
sudo rm -f /usr/lib64/libastal.so*
sudo rm -f /usr/lib64/libastal-4.so*

# Remove Astal service libraries
sudo rm -f /usr/lib64/libastal-apps.so*
sudo rm -f /usr/lib64/libastal-battery.so*
sudo rm -f /usr/lib64/libastal-bluetooth.so*
sudo rm -f /usr/lib64/libastal-hyprland.so*
sudo rm -f /usr/lib64/libastal-mpris.so*
sudo rm -f /usr/lib64/libastal-network.so*
sudo rm -f /usr/lib64/libastal-notifd.so*
sudo rm -f /usr/lib64/libastal-powerprofiles.so*
sudo rm -f /usr/lib64/libastal-wireplumber.so*

# Remove pkg-config files
sudo rm -f /usr/lib64/pkgconfig/astal*.pc

# Remove header files
sudo rm -rf /usr/include/astal*
```

**Verification:**
```bash
ls /usr/lib64/libastal*.so* 2>/dev/null
# Should return: "No such file or directory"

pkg-config --list-all | grep astal
# Should return: nothing
```

### 7. Cache and Build Artifacts

Clean up Meson and npm caches if they were created:

```bash
# Clear npm cache for HyprPanel (if it was cached)
npm cache clean --force

# No specific Meson cache to clean (per-project)
```

## Complete Verification Checklist

Run these commands to verify complete cleanup:

```bash
echo "=== Comprehensive Cleanup Verification ==="

echo -e "\n1. Temporary directories:"
for dir in /tmp/hyprpanel-build /tmp/ags /tmp/astal; do
    if [ -d "$dir" ]; then
        echo "  ✗ $dir still exists"
    else
        echo "  ✓ $dir removed"
    fi
done

echo -e "\n2. Installation scripts:"
cd /home/kuba/aiTools
for script in install_hyprpanel*.sh INSTALL_HYPRPANEL*.sh; do
    if [ -f "$script" ]; then
        echo "  ✗ $script still exists"
    else
        echo "  ✓ $script removed"
    fi
done

echo -e "\n3. Patcher tools:"
for patcher in patch_*.py patch_*.sh manual_*.sh simple_*.sh; do
    if [ -f "$patcher" ]; then
        echo "  ✗ $patcher still exists"
    else
        echo "  ✓ $patcher removed"
    fi
done

echo -e "\n4. Binaries:"
which ags hyprpanel &>/dev/null && echo "  ✗ Binaries still installed" || echo "  ✓ Binaries removed"

echo -e "\n5. Astal libraries:"
ls /usr/lib64/libastal*.so* &>/dev/null && echo "  ✗ Libraries still installed" || echo "  ✓ Libraries removed"

echo -e "\n6. Shared data:"
for dir in /usr/share/astal /usr/share/hyprpanel; do
    if [ -d "$dir" ]; then
        echo "  ✗ $dir still exists"
    else
        echo "  ✓ $dir removed"
    fi
done

echo -e "\n=== Cleanup complete! ==="
```

## What to Keep

**Do NOT remove these:**
- `/home/kuba/aiTools/linux/convos/HyprPanel.md` - Journey documentation
- `/home/kuba/aiTools/linux/convos/CLEANUP.md` - This cleanup guide
- Standard system packages: `vala`, `gobject-introspection-devel`, `meson`, `ninja`
- Your existing Hyprland configuration and waybar setup

## Recommended Packages to Keep

These are general development tools that might be useful for other projects:

**Keep:**
- `vala` - Vala compiler (useful for other GNOME/GTK projects)
- `gobject-introspection-devel` - Required by many GTK applications
- `gtk-layer-shell-devel` - Useful for Wayland overlay projects
- `gtk4-layer-shell-devel` - Same as above for GTK4
- `meson`, `ninja` - Common build tools
- `npm`, `node` - JavaScript/TypeScript development

**Optional to remove** (only if you installed them just for HyprPanel):
- `json-glib-devel` - Keep if you develop with JSON in C/Vala
- `pam-devel` - Keep if you develop authentication modules
- `sass` (npm global) - Keep if you use Sass/SCSS for styling

Check what depends on a package before removing:
```bash
# Example: Check what needs json-glib-devel
zypper se --requires json-glib-devel

# Example: Check what needs pam-devel
zypper se --requires pam-devel
```

## Disk Space Recovery

Expected space recovered:

```bash
# Temporary build directories
/tmp/hyprpanel-build  ~50 MB
/tmp/ags              ~30 MB
/tmp/astal            ~20 MB (if cloned separately)

# Installed binaries
/usr/share/hyprpanel  ~15 MB
/usr/share/astal      ~5 MB

# Astal libraries
/usr/lib64/libastal*  ~10 MB

# Scripts and patchers
/home/kuba/aiTools/*  ~500 KB

Total: ~130 MB
```

## Post-Cleanup

After cleanup, you can proceed with the recommended alternative:

**Option 1: Style Waybar with Gruvbox** (Recommended)
```bash
# Waybar is already working on your system
# Create custom Gruvbox theme in:
# ~/.config/waybar/style.css

# Gruvbox color palette for reference:
# Background: #282828
# Foreground: #ebdbb2
# Red:        #cc241d
# Orange:     #d65d0e (already in your Hyprland config!)
# Yellow:     #d79921
# Green:      #98971a
# Blue:       #458588
# Purple:     #b16286
# Aqua:       #689d6a
```

**Option 2: Try HyprPanel on Different Distro**

If you really want HyprPanel, consider:
- Arch Linux: `yay -S ags-hyprpanel-git` (in AUR)
- NixOS: `programs.hyprpanel.enable = true;`
- Ubuntu/Debian: Might have similar valadoc issues

**Option 3: Wait for Upstream Fixes**

Monitor these repositories for updates:
- https://github.com/HyprPanel/HyprPanel
- https://github.com/Aylur/astal
- https://github.com/Aylur/ags

The valadoc issue might be fixed in future Vala releases or Astal updates.

## Summary

This cleanup removes:
- ✓ All temporary build directories (~100 MB)
- ✓ All installation scripts (7 files)
- ✓ All patcher tools (7 files)
- ✓ Non-functional HyprPanel installation
- ✓ Non-functional Astal libraries (if you choose)
- ✓ AGS CLI (if you choose)

This preserves:
- ✓ Documentation of the journey
- ✓ Your existing Hyprland/waybar setup
- ✓ Standard development packages
- ✓ Lessons learned for future attempts

## Questions?

If you're unsure about removing something:
1. Check what depends on it: `zypper se --requires <package>`
2. Keep documentation files for reference
3. When in doubt, keep system packages and only remove temp directories

---

**End of cleanup guide. Your system will be back to pre-HyprPanel state after running these commands.**
