# Waybar Customisation Session

**Date**: 2025-11-17
**Session Goal**: Improve Waybar styling with larger fonts and dual-monitor support with toggle functionality

---

## Initial Requirements

1. **Increase font size** and adjust element sizing to match
2. **Dual display setup**: Waybar on both monitors
3. **Toggle functionality**: Hide/show Waybar on wider display (DP-4) with `SUPER+Z`

---

## System Configuration

### Display Setup
- **DP-6**: 2560x1440@60Hz (narrower display, always visible)
- **DP-4**: 3440x1440@144Hz (wider display, toggleable)

### Font Stack
- Primary: **JetBrainsMono Nerd Font** (installed at `~/.local/share/fonts/`)
- Fallbacks: Font Awesome 6 Free, Symbols Nerd Font, Cantarell

---

## Changes Made

### 1. Font Size & Weight Adjustments

#### Initial State (Original Config)
```css
font-family: "Cantarell", "Font Awesome 5 Pro";
font-size: 9pt;
font-weight: bold;
```

#### Iteration 1 - Large Size (Too Dominating)
```css
font-size: 13pt;
font-weight: 600;
```
- **Result**: Bar height ~59px - too large and dominating
- **Issue**: Increased readability but overwhelmed the desktop

#### Final Configuration (Optimal Balance)
```css
font-family: "JetBrainsMono Nerd Font", "JetBrainsMono NF", "Font Awesome 6 Free", "Symbols Nerd Font", "Cantarell";
font-size: 11pt;
font-weight: 800;  /* Extra Bold */
```
- **Result**: Bar height ~49-52px
- **Outcome**: Excellent readability without being dominating
- **Key Insight**: Bold weight (800) more effective than size increase alone

### 2. Arrow Separator Scaling

Powerline arrows needed proportional scaling to match font changes:

```css
/* Original */
#custom-arrow1-8 { font-size: 2.0em; }

/* First adjustment (13pt font) */
#custom-arrow1-8 { font-size: 2.4em; }

/* Final (11pt font) */
#custom-arrow1 { font-size: 2.2em; }
#custom-arrow4 { font-size: 2.3em; }
#custom-arrow5 { font-size: 2.32em; }
```

### 3. Module Padding Adjustments

```css
/* Original */
padding: 0.6em 0.8em;

/* Final */
padding: 0.5em 1.0em;
```

---

## Dual Monitor Configuration

### Architecture

Created separate config files for each display:
- `config-dp4.json` - DP-4 (wider monitor with toggle button)
- `config-dp6.json` - DP-6 (narrower monitor, identical layout)

### Launch Script: `launch-waybar.sh`

```bash
#!/bin/bash
# Launch dual-monitor Waybar setup

killall waybar
sleep 0.5

# Launch for both displays
waybar -c ~/.config/waybar/config-dp6.json -s ~/.config/waybar/style.css &
waybar -c ~/.config/waybar/config-dp4.json -s ~/.config/waybar/style.css &
```

**Hyprland Integration**:
```
exec-once = swaync & hypridle & ~/.config/waybar/launch-waybar.sh
```

---

## Toggle Functionality

### Toggle Script: `scripts/toggle-waybar-dp4.sh`

#### Initial (Broken) Version
```bash
pkill -SIGUSR1 -f 'waybar.*bar-dp4'
```
**Issue**: Pattern didn't match actual process command line

#### Fixed Version
```bash
#!/bin/bash
# Find the Waybar process for DP-4 and send SIGUSR1 to toggle visibility
pkill -SIGUSR1 -f 'waybar.*config-dp4.json'
```

**How It Works**:
- Waybar responds to `SIGUSR1` signal by toggling visibility
- Process command line: `waybar -c /home/kuba/.config/waybar/config-dp4.json -s ...`
- Pattern `waybar.*config-dp4.json` matches the DP-4 instance only

### Hyprland Keybinding

Added to `~/.config/hypr/hyprland.conf` at line 240:
```
bind = $mainMod, Z, exec, ~/.config/waybar/scripts/toggle-waybar-dp4.sh
```

---

## Critical Lessons Learned

### 1. UTF-8 Character Preservation

**Problem**: Powerline arrow characters (U+E0B0: ) disappeared when creating new config files.

**Cause**: The Write tool doesn't preserve special Unicode characters when writing files.

**Solution**:
- Copy existing configs with `cp` command
- Use `sed` for minimal modifications only
- Never recreate config files from scratch if they contain Nerd Font glyphs

**Verification Method**:
```bash
# Check UTF-8 bytes are present
hexdump -C config.json | grep -A1 "arrow1"
# Look for: ee 82 b0 (UTF-8 for U+E0B0)
```

### 2. Font Weight More Effective Than Size

**Discovery**:
- Increasing font size from 11pt → 13pt made bars too large
- Increasing font weight from 600 → 800 improved readability without height increase

**Recommendation**: Try font-weight adjustments before increasing font-size

### 3. Arrow Color Coordination

**Issue**: When modules were removed/reordered, arrows appeared "scattered"

**Cause**: Arrow colors in CSS are hardcoded to create visual sections. Removing modules breaks the color flow.

**Solution**: Keep module layouts identical across displays, only varying:
- Output designation (`"output": "DP-4"` vs `"DP-6"`)
- Display-specific modules (like toggle button)

---

## Module Layout Structure

### Both Displays (Identical)

```json
"modules-left": [
  "network", "bluetooth",
  "custom/arrow1",
  "custom/waybar-toggle",  // Only on DP-4
  "custom/arrow2",
  "idle_inhibitor",
  "custom/arrow3",
  "tray",
  "custom/playerctl"
],
"modules-center": [
  "custom/arrow4",
  "hyprland/workspaces",
  "custom/arrow5"
],
"modules-right": [
  "hyprland/window",
  "custom/arrow6",
  "custom/weather",
  "custom/arrow7",
  "temperature", "cpu", "memory", "gpu",
  "custom/arrow8",
  "pulseaudio",
  "clock#time", "clock#date"
]
```

### Toggle Button (DP-4 Only)

```json
"custom/waybar-toggle": {
  "format": "󰍉",
  "tooltip-format": "Toggle Waybar (SUPER+Z)",
  "on-click": "~/.config/waybar/scripts/toggle-waybar-dp4.sh"
}
```

---

## File Locations

### Active Configs
```
~/.config/waybar/
├── config-dp4.json          # DP-4 (3440x1440)
├── config-dp6.json          # DP-6 (2560x1440)
├── style.css                # Shared styles
├── launch-waybar.sh         # Launch script
└── scripts/
    └── toggle-waybar-dp4.sh # Toggle script
```

### Staging Repository
```
~/aiTools/linux/configs/waybar/
├── config-dp4.json
├── config-dp6.json
├── style.css
├── launch-waybar.sh
├── scripts/
│   └── toggle-waybar-dp4.sh
└── README.md
```

### Hyprland Config
```
~/.config/hypr/hyprland.conf
  - Line 51: exec-once with launch script
  - Line 240: SUPER+Z keybinding
```

---

## Final Specifications

| Property | Value |
|----------|-------|
| Font Family | JetBrainsMono Nerd Font |
| Font Size | 11pt |
| Font Weight | 800 (Extra Bold) |
| Bar Height | ~49-52px (auto) |
| Arrow Size | 2.2-2.32em |
| Module Padding | 0.5em 1.0em |

---

## Testing & Verification

### Check Running Processes
```bash
ps aux | grep waybar
# Should show two processes:
# waybar -c ~/.config/waybar/config-dp6.json ...
# waybar -c ~/.config/waybar/config-dp4.json ...
```

### Test Toggle
```bash
# Via script
~/.config/waybar/scripts/toggle-waybar-dp4.sh

# Via keyboard
# Press SUPER+Z
```

### Reload Configuration
```bash
~/.config/waybar/launch-waybar.sh
```

### Verify Font Rendering
```bash
# Check available Nerd Fonts
fc-list | grep -i "nerd"

# Test UTF-8 characters in terminal
printf '\xee\x82\xb0'  # Should show:
```

---

## Future Customization Notes

### Changing Module Layout

1. **Edit both config files** (`config-dp4.json` and `config-dp6.json`)
2. Keep module lists synchronized (except toggle button)
3. Ensure arrow separators align with module sections
4. Test on both displays after changes

### Modifying Colors

Arrow colors are defined in `style.css`:
```css
#custom-arrow1 {
    color: @bg;              /* Arrow fill color */
    background: @bluetint;   /* Section background */
}
```

Color scheme uses Gruvbox Dark variables defined at top of `style.css`.

### Adding New Modules

1. Add module to appropriate section in both configs
2. Add module definition (if custom)
3. Consider if arrows need adjustment
4. Add CSS styling if needed
5. Test reload

### Font Size Adjustments

If modifying font size again:
- Adjust arrows proportionally (~2× base font size in em)
- Consider font-weight before increasing size
- Test on both displays
- Verify bar height is acceptable

---

## Common Issues & Solutions

### Issue: Icons Not Displaying

**Symptoms**: Boxes or missing glyphs where icons should be

**Solutions**:
1. Verify Nerd Font is installed: `fc-list | grep -i nerd`
2. Check font-family in CSS includes Nerd Font first
3. Ensure UTF-8 characters preserved in config (use hexdump)
4. Never use Write tool for files with Unicode glyphs

### Issue: Toggle Not Working

**Symptoms**: SUPER+Z does nothing

**Diagnostics**:
```bash
# Check if processes exist
ps aux | grep waybar

# Test script manually
~/.config/waybar/scripts/toggle-waybar-dp4.sh

# Verify keybinding loaded
hyprctl binds | grep toggle
```

**Solutions**:
1. Verify script pattern matches process: `pkill -SIGUSR1 -f 'waybar.*config-dp4.json'`
2. Ensure script is executable: `chmod +x ~/.config/waybar/scripts/toggle-waybar-dp4.sh`
3. Reload Hyprland config: `hyprctl reload`

### Issue: Bars on Wrong Displays

**Symptoms**: Waybar appears on wrong monitor

**Solution**:
- Verify `"output"` field in each config matches monitor names
- Check monitor names: `hyprctl monitors`
- Ensure DP-4 and DP-6 match your actual display IDs

### Issue: "Scattered" or Misaligned Modules

**Symptoms**: Modules appear oddly spaced or separated

**Cause**: Arrow colors don't match adjacent modules

**Solution**: Keep both config files' module layouts identical except for display-specific modules like toggle button

---

## Deployment Workflow

### From Staging to System

```bash
# Deploy all configs
rsync -av ~/aiTools/linux/configs/waybar/ ~/.config/waybar/

# Reload Waybar
~/.config/waybar/launch-waybar.sh

# If Hyprland config changed
hyprctl reload
```

### From System to Staging

```bash
# Backup current configs
rsync -av ~/.config/waybar/ ~/aiTools/linux/configs/waybar/ \
  --exclude="*.log" --exclude="cache"
```

---

## References

- [Waybar Wiki](https://github.com/Alexays/Waybar/wiki)
- [Nerd Fonts](https://www.nerdfonts.com/)
- [Hyprland Binds](https://wiki.hyprland.org/Configuring/Binds/)
- Font Awesome 6 Cheatsheet: https://fontawesome.com/search
- Nerd Fonts Cheat Sheet: https://www.nerdfonts.com/cheat-sheet

---

## Session Summary

**Total Changes**:
- 2 config files created (DP-4, DP-6)
- 1 stylesheet updated
- 1 launch script created
- 1 toggle script fixed
- 2 Hyprland config modifications

**Outcome**: Dual-monitor Waybar with improved readability, balanced appearance, and working toggle functionality on DP-4 via SUPER+Z.

**Key Success Factors**:
1. Font weight over font size for readability
2. UTF-8 character preservation via copy/sed workflow
3. Synchronized module layouts across displays
4. Proper process matching in toggle script
