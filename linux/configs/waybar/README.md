# Waybar Dual-Monitor Setup

This configuration provides a dual-monitor Waybar setup with improved font sizing and per-monitor customization.

## Features

- **Increased font size**: Base font increased from 9pt to 13pt for better readability
- **Dual-monitor support**:
  - `config-dp6.json` - Always visible bar on DP-6 (2560x1440@60Hz)
  - `config-dp4.json` - Toggleable bar on DP-4 (3440x1440@144Hz)
- **Keyboard toggle**: Press `SUPER+Z` to toggle the Waybar on DP-4
- **Proportional sizing**: Arrow separators and padding adjusted to match larger font

## File Structure

```
~/.config/waybar/
├── config-dp4.json          # Config for DP-4 (wider monitor with toggle)
├── config-dp6.json          # Config for DP-6 (always visible)
├── style.css                # Shared styles for both bars
├── launch-waybar.sh         # Launch script for both instances
└── scripts/
    └── toggle-waybar-dp4.sh # Toggle script for DP-4 bar
```

## Changes from Original

### Font Sizing
- Base font: 9pt → 13pt
- Arrow separators: 2.0em → 2.4em (2.1em → 2.5em for center arrows)
- Module padding: 0.6em 0.8em → 0.5em 1.0em

### Display Configuration
- **DP-6 Config**: Standard modules without toggle button
- **DP-4 Config**: Includes toggle button with icon (󰍉) and tooltip

### Hyprland Integration
Added keybinding in `~/.config/hypr/hyprland.conf`:
```
bind = $mainMod, Z, exec, ~/.config/waybar/scripts/toggle-waybar-dp4.sh
```

Updated autostart:
```
exec-once = swaync & hypridle & ~/.config/waybar/launch-waybar.sh
```

## Deployment

From the staging repository:
```bash
rsync -av /home/kuba/aiTools/linux/configs/waybar/ ~/.config/waybar/
```

## Testing

Launch manually:
```bash
~/.config/waybar/launch-waybar.sh
```

Toggle DP-4 bar:
```bash
# Via keyboard
SUPER+Z

# Via script
~/.config/waybar/scripts/toggle-waybar-dp4.sh
```

## Troubleshooting

### Bar height warnings
The bars automatically adjust height to accommodate content. Current setup requires 52px height for 13pt font.

### Toggle not working
Ensure the script is executable:
```bash
chmod +x ~/.config/waybar/scripts/toggle-waybar-dp4.sh
```

Verify Hyprland config was reloaded:
```bash
hyprctl reload
```

### Weather module not loading
The weather module uses `curl` to fetch data from wttr.in. Initial load may take a few seconds.
