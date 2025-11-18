# Hyprscrolling Configuration - Column Management

**Date:** 2025-11-15
**System:** Almalexia (OpenSUSE Tumbleweed)
**Desktop:** Hyprland (Wayland)

## Problem Statement

After installing the hyprscrolling plugin for Hyprland (via OpenSUSE's unorthodox installation method), the basic functionality worked but controlling the number of columns per workspace was unclear. The goal was to create quick keybindings to switch between 2, 3, and 4 column layouts on the current workspace.

## Solution Overview

Configured quick column presets using the `layoutmsg` dispatcher with `colresize all` command to resize all columns in a workspace to equal widths.

## Final Keybindings

```
# Quick column presets (resize all columns equally)
bind = $mainMod, comma, layoutmsg, colresize all 0.5     # SUPER+, → 2 columns (50% each)
bind = $mainMod, period, layoutmsg, colresize all 0.3334 # SUPER+. → 3 columns (33.34% each)
bind = $mainMod, slash, layoutmsg, colresize all 0.25    # SUPER+/ → 4 columns (25% each)
```

### Additional Bindings

```
# Add/remove columns dynamically
bind = $mainMod CTRL, bracketright, layoutmsg, +col
bind = $mainMod CTRL, bracketleft, layoutmsg, -col

# Move windows between columns
bind = $mainMod SHIFT, h, layoutmsg, movewindowto l
bind = $mainMod SHIFT, l, layoutmsg, movewindowto r
bind = $mainMod SHIFT, j, layoutmsg, movewindowto u
bind = $mainMod SHIFT, k, layoutmsg, movewindowto d
```

## Plugin Configuration

```
plugin {
    hyprscrolling {
        column_default_width = one_half  # default to 2 columns (50% each)
        fullscreen_on_one_column = true
        focus_fit_method = 1
        follow_focus = true
    }
}
```

## Key Technical Details

### Installation

- Plugin loaded from: `/usr/lib64/hyprland/plugins/hyprscrolling.so`
- OpenSUSE packages the plugin in a system location rather than user-compiled

### Syntax Issues Discovered

**Problem:** Initial keybindings used parentheses syntax:
```
bind = $mainMod, period, layoutmsg, colresize all(0.5)   # ❌ Did not work
```

**Solution:** Hyprland's bind parser expects space-separated arguments:
```
bind = $mainMod, period, layoutmsg, colresize all 0.5    # ✅ Works correctly
```

The commands work when dispatched manually via `hyprctl dispatch layoutmsg 'colresize all(0.5)'` but **not** when bound in the config file with parentheses.

### Width Calibration

- **2 columns:** `0.5` (exactly 50% each)
- **3 columns:** `0.3334` provides the closest visual fit to full screen width
  - Initially tried `0.334` but columns were slightly too wide
  - Adjusted to `0.33` (too narrow)
  - Final value `0.3334` accounts for gaps and borders perfectly
- **4 columns:** `0.25` (exactly 25% each)

## Usage

1. **Quick preset switching:**
   - Press `SUPER + ,` to instantly resize all columns to 2-column layout
   - Press `SUPER + .` to instantly resize all columns to 3-column layout
   - Press `SUPER + /` to instantly resize all columns to 4-column layout

2. **Dynamic column management:**
   - `SUPER + CTRL + ]` adds a new column
   - `SUPER + CTRL + [` removes a column

3. **Window movement:**
   - `SUPER + SHIFT + H/L` moves active window left/right between columns
   - `SUPER + SHIFT + J/K` moves active window up/down within column

## Config Location

- **Repository:** `/home/kuba/aiTools/linux/configs/hyprland/hyprland.conf`
- **Deployed:** `~/.config/hypr/hyprland.conf`

### Deployment Workflow

```bash
# Sync changes from repository to active config
rsync -av /home/kuba/aiTools/linux/configs/hyprland/ ~/.config/hypr/

# Reload Hyprland configuration
hyprctl reload
```

## Verification Commands

```bash
# Check if plugin is loaded
hyprctl plugin list

# Verify current layout
hyprctl getoption general:layout
# Should show: str: scrolling

# Test column resize manually
hyprctl dispatch layoutmsg 'colresize all 0.5'

# View current keybindings
hyprctl binds | grep -i colresize

# Check window positions on workspace
hyprctl clients | grep -E 'workspace:|at:'
```

## Notes

- Commands only affect the **current workspace**
- Multiple windows must be open for column resizing to be visible
- The `all` parameter in `colresize all <width>` resizes every column to the same width
- Individual column resizing is also possible with `colresize +0.1` or `colresize -0.1` for relative adjustments
- The plugin integrates seamlessly with Hyprland's workspace and monitor management

## References

- Plugin source: https://github.com/hyprwm/hyprland-plugins/tree/main/hyprscrolling
- Hyprland wiki: https://wiki.hyprland.org/
- OpenSUSE specific installation path: `/usr/lib64/hyprland/plugins/`
