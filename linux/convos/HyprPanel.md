# HyprPanel Installation Attempt - OpenSUSE Tumbleweed

**Date:** 2025-11-16
**Status:** ❌ Unsuccessful
**System:** OpenSUSE Tumbleweed (Almalexia workstation)

## Goal
Install HyprPanel to replace waybar, specifically to get the beautiful Gruvbox theme.

## Summary
After extensive troubleshooting and multiple build attempts, HyprPanel installation on OpenSUSE Tumbleweed failed due to fundamental incompatibilities between:
- Vala 0.56.18 and valadoc
- GJS 1.86.0 and old AGS packages
- GObject Introspection requirements

## The Problem

HyprPanel (as of Nov 2025) is built on **Astal**, which requires:
1. **Building C libraries** from Vala source → Works ✓
2. **Generating GIR/typelib files** for JavaScript bindings → **Fails ✗**

### The Catch-22
- **Can't build WITH GIR:** valadoc has bugs with parameter documentation annotations
- **Can't run WITHOUT GIR:** HyprPanel needs typelib files to call C libraries from JavaScript

### Root Cause
```
Error: valadoc generates warnings on @param documentation
→ gir.py script fails
→ No typelib files generated
→ HyprPanel can't load Astal libraries
→ Runtime error: "Typelib file for namespace 'AstalNotifd' not found"
```

## What We Tried

### 1. Initial Setup Issues
**Problem:** Old `aylurs-gtk-shell` (v1.8.2) incompatible with GJS 1.86.0
```bash
# Error
TypeError: Repository.prepend_search_path is not a function
```

**Solution:** Removed old AGS package
```bash
sudo zypper remove aylurs-gtk-shell
```

### 2. Building Astal from Source

#### Dependencies Installed
```bash
# Core build tools (already present)
vala 0.56.18
gobject-introspection-devel
gtk-layer-shell-devel
gtk4-layer-shell-devel
meson, ninja, npm

# Additional dependencies needed
sudo zypper install json-glib-devel  # For service libraries
sudo zypper install pam-devel         # For astal-auth
sudo npm install -g sass              # dart-sass for styling
```

#### Build Attempts

**Attempt 1: Standard Build**
```bash
cd astal/lib/astal/io
meson setup build --prefix=/usr
meson compile -C build
```
**Result:** Failed at GIR generation step
```
FAILED: AstalIO-0.1.gir
process.vala: AstalIO.Process.write_async: @param: warning: Unknown parameter `in'
```

**Attempt 2: Disable Introspection**
```bash
meson setup build --prefix=/usr -Dintrospection=false
```
**Result:** Flag ignored (not implemented in Astal's meson.build)

**Attempt 3-7: Patching meson.build Files**

Created multiple Python patchers to remove GIR generation blocks:
- `patch_astal_gir.py` - regex-based (failed)
- `patch_astal_simple.py` - line-by-line (failed)
- `patch_astal_fixed.py` - lookahead detection (failed)
- `patch_astal_working.py` - two-pass deletion (✓ **worked!**)

**Final working patcher:**
```python
# Pass 1: Mark all GIR-related lines for deletion
# Pass 2: Remove marked lines
# Handled three patterns:
# - gir_tgt = custom_target(...)
# - gir = custom_target(...)
# - custom_target(...) with typelib dependency
```

**Files patched:**
- `/tmp/hyprpanel-build/astal/lib/astal/io/meson.build` (14 lines)
- `/tmp/hyprpanel-build/astal/lib/astal/gtk3/src/meson.build` (38 lines)
- `/tmp/hyprpanel-build/astal/lib/astal/gtk4/src/meson.build` (34 lines)
- Service libraries: apps, battery, bluetooth, hyprland, mpris, network, notifd, powerprofiles, tray (30-39 lines each)

**Result:** ✓ All Astal libraries built successfully WITHOUT GIR

### 3. Building AGS CLI
HyprPanel build requires `ags bundle` command.

```bash
cd /tmp
git clone https://github.com/Aylur/ags.git
cd ags
npm install
meson setup build --prefix=/usr
meson compile -C build
sudo meson install -C build
```
**Result:** ✓ AGS CLI installed successfully

### 4. Building HyprPanel
```bash
cd /tmp/hyprpanel-build/HyprPanel
rm package-lock.json  # Fix npm dependency issue
npm install
meson setup build --prefix=/usr
meson compile -C build
sudo meson install -C build
./scripts/install_fonts.sh
```
**Result:** ✓ Build successful, installed to `/usr`

### 5. Runtime Failure
```bash
$ hyprpanel

Error: Requiring AstalNotifd, version none: Typelib file for namespace
'AstalNotifd' (any version) not found
```

**Root cause:** HyprPanel needs the GIR/typelib files we removed to make the build work.

## Technical Deep Dive

### Why GIR/Typelib is Required

**GObject Introspection Flow:**
```
Vala source code (.vala)
    ↓ valac
C library (.so)
    ↓ valadoc + gir.py
GIR file (.gir) [XML description of API]
    ↓ g-ir-compiler
Typelib file (.typelib) [Binary for runtime]
    ↓ JavaScript/Python imports
Can call C library from scripting languages
```

HyprPanel is written in **TypeScript/JavaScript** running on **GJS runtime**, which requires typelib files to call the Astal C libraries.

### The valadoc Bug

**Affected files:** All Astal Vala source files
**Error pattern:**
```
process.vala: AstalIO.Process.write_async: @param: warning: Unknown parameter `in'
process.vala: AstalIO.Process.write: @param: warning: Unknown parameter `in'
process.vala: AstalIO.Process.stdout: @param: warning: Unknown parameter `out'
```

**Why it happens:**
- Vala code uses `in` and `out` as parameter direction modifiers
- valadoc documentation parser doesn't recognize these in @param tags
- gir.py script treats warnings as fatal errors

**Potential fixes (not attempted):**
1. Patch Astal source to fix documentation
2. Update valadoc to handle these cases
3. Modify gir.py to ignore warnings
4. Use older/newer Vala version

## Lessons Learned

1. **HyprPanel = Astal + AGS CLI**
   - Astal: C libraries (backend)
   - AGS: TypeScript bundler and runtime wrapper
   - Both required for HyprPanel

2. **OpenSUSE Package Issues**
   - `aylurs-gtk-shell` package is outdated (v1.8.2)
   - Incompatible with GJS 1.86.0
   - Must be removed before building

3. **GIR is Not Optional**
   - Can't skip for JavaScript-based applications
   - Required at runtime, not just build time
   - No workaround without fixing valadoc issues

4. **Dependency Chain**
   ```
   HyprPanel → AGS CLI → Astal (C libs) → GIR/typelib → valadoc → Vala source
                                              ↑ BREAKS HERE
   ```

5. **Missing Optional Dependencies** (skipped during build)
   - `astal-auth`: requires PAM (installed but not built)
   - `astal-tray`: requires `appmenu-glib-translator` (not in repos)

## Build Artifacts Created

### Successfully Built & Installed
- ✓ astal-io (0.1.0)
- ✓ astal3 / libastal.so.3.0.0 (GTK3 widgets)
- ✓ astal4 / libastal-4.so.4.0.0 (GTK4 widgets)
- ✓ astal-apps
- ✓ astal-battery
- ✓ astal-bluetooth
- ✓ astal-hyprland
- ✓ astal-mpris
- ✓ astal-network
- ✓ astal-notifd
- ✓ astal-powerprofiles
- ✓ astal-wireplumber
- ✓ AGS CLI (`/usr/bin/ags`)
- ✓ HyprPanel binaries (`/usr/share/hyprpanel/`, `/usr/bin/hyprpanel`)

### Missing (Build Skipped)
- ✗ astal-auth (PAM dependency - optional)
- ✗ astal-tray (appmenu-glib-translator - not available)
- ✗ **All GIR/typelib files** (removed to fix build)

## Alternative Approaches Considered

1. **Use AGS v1** (old but stable)
   - Pros: More mature, better OpenSUSE compatibility
   - Cons: Deprecated, different architecture

2. **Build on Different Distro**
   - Arch Linux has `ags-hyprpanel-git` in AUR
   - NixOS has `programs.hyprpanel.enable`

3. **Fix valadoc Issues**
   - Patch Astal source documentation
   - Too time-consuming for desired outcome

4. **Style Waybar Instead** ⭐ **Recommended**
   - Already working on system
   - Highly customizable
   - Gruvbox theme achievable with CSS
   - Much simpler and reliable

## Files & Scripts Created

### Installation Scripts
- `/home/kuba/aiTools/install_hyprpanel.sh` - Original (failed)
- `/home/kuba/aiTools/install_hyprpanel_fixed.sh` - With meson flag (failed)
- `/home/kuba/aiTools/install_hyprpanel_patched.sh` - First patcher (failed)
- `/home/kuba/aiTools/install_hyprpanel_v3.sh` - Better patcher (failed)
- `/home/kuba/aiTools/INSTALL_HYPRPANEL_FINAL.sh` - Final working build script ✓

### Patching Tools
- `/home/kuba/aiTools/patch_astal_gir.py` - Regex approach
- `/home/kuba/aiTools/patch_astal_simple.py` - Line-by-line parser
- `/home/kuba/aiTools/patch_astal_fixed.py` - Lookahead detection
- `/home/kuba/aiTools/patch_astal_working.py` - ⭐ **Working two-pass patcher**
- `/home/kuba/aiTools/patch_use_vala_gir.py` - Incomplete attempt
- `/home/kuba/aiTools/manual_patch_astal.sh` - Abandoned awk approach
- `/home/kuba/aiTools/simple_sed_patch.sh` - Abandoned sed approach

### Documentation
- `/home/kuba/aiTools/HYPRPANEL_SETUP.md` - Installation guide
- `/home/kuba/aiTools/linux/convos/HyprPanel.md` - This file

## Cleanup Required

See `CLEANUP.md` for detailed cleanup instructions.

## Recommendation

**Switch to Waybar with Gruvbox theme** instead of HyprPanel:
- Waybar is mature, stable, and already working
- Highly customizable with CSS
- Can achieve similar Gruvbox aesthetics
- No complex build dependencies
- OpenSUSE package available: `waybar`

### Waybar Gruvbox Resources
- https://github.com/Alexays/Waybar
- Gruvbox theme examples in `/usr/share/waybar/examples/`
- Custom CSS: `~/.config/waybar/style.css`

## Timeline

**Total time spent:** ~4 hours
**Build attempts:** 8+
**Patcher iterations:** 7
**Dependencies installed:** 5
**Final status:** Builds successfully but won't run

## Technical Specs

```yaml
System:
  OS: OpenSUSE Tumbleweed
  Kernel: 6.17.7-1-default
  DE: Hyprland (Wayland)
  Shell: zsh / ghostty

Software Versions:
  Vala: 0.56.18
  GJS: 1.86.0
  Meson: 1.9.1
  Node: v22.15.1
  npm: 10.9.2

Astal:
  Commit: 5baeb66 (latest as of 2025-11-16)
  Libraries built: 12/14

AGS CLI:
  Commit: Latest (2025-11-16)
  Status: Installed

HyprPanel:
  Commit: Latest (2025-11-16)
  Status: Installed but non-functional
```

## Conclusion

While we successfully built all components, HyprPanel cannot run on OpenSUSE Tumbleweed without GIR/typelib files, which cannot be generated due to valadoc compatibility issues with the current Vala/Astal versions.

**The fundamental incompatibility is:**
```
Astal (2025) + Vala (0.56.18) + valadoc → GIR generation fails
HyprPanel → Requires GIR/typelib → Cannot run
```

This is not a configuration issue but a **toolchain compatibility problem** that would require upstream fixes in either:
- Astal (fix documentation syntax)
- valadoc (handle parameter direction modifiers)
- HyprPanel (provide pre-built typelibs)

**Recommended next step:** Configure Waybar with Gruvbox theme instead.
