# YAML QuickLook Extension for macOS

A modern, fast, and feature-rich macOS Quick Look Preview Extension for viewing `.yaml` and `.yml` files in **DEVONthink** and **Finder**.

Built natively with Swift and modern App Extension APIs (`com.apple.quicklook.preview`).

---

## Key Features

- **Full DEVONthink & Finder Integration**:
  - **Finder Selection / Preview Pane**: Automatically displays a native, scrollable raw text view in Finder's column view and Inspector pane (just like Markdown and source code files).
  - **Full-Screen Quick Look**: Press <kbd>Space</kbd> in Finder or DEVONthink for rich syntax highlighting, code folding, dark mode, and soft wrap toggle.
  - **DEVONthink**: Renders directly inside DEVONthink's preview and inspector panes via `QLPreviewView`.
- **Soft Line Wrapping (Raw & Highlighted Mode)**:
  - Toggle soft wrapping with a single click using the **Wrap: On / Wrap: Off** toolbar button.
  - In **Raw mode**, long lines wrap smoothly to avoid horizontal scrolling.
  - Configurable default wrapping behavior in the companion app settings.
- **YAML Syntax Highlighting**:
  - Keys, double/single-quoted strings, unquoted scalar values.
  - Numbers (integers, floats, hex `0x`, octal `0o`, `.nan`, `.inf`).
  - Booleans (`true`, `false`, `yes`, `no`, `on`, `off`), nulls (`null`, `~`, `nil`), and ISO dates/timestamps.
  - YAML Anchors (`&anchor`), Aliases (`*anchor`), and merge keys (`<<: *anchor`).
  - Tags (`!include`, `!!str`, `!secret`), multi-line block scalar headers (`|`, `>`).
  - Comments (`# ...`) and document dividers (`---`, `...`).
- **Interactive Code Folding**:
  - Collapsible nested YAML mappings and sequences.
  - Click the fold indicator (`▾` / `▸`) to collapse deep structures like Kubernetes manifests or Docker Compose services.
  - Quick **Expand All** and **Collapse All** buttons.
- **YAML Syntax Validation & Error Diagnostics**:
  - Automatically detects YAML syntax issues (e.g. forbidden tab characters in indentation, unclosed quotes, duplicate keys).
  - Shows a green `✓ Valid YAML` badge or a red `⚠ Error (Line X)` badge.
  - Clicking the error badge jumps and scrolls directly to the offending line.
- **Appearance & Dark/Light Mode**:
  - Automatically matches DEVONthink and macOS system appearance via `@media (prefers-color-scheme: dark)`.
  - Multiple color themes: System Adaptive, Xcode, GitHub, Monokai, Dracula, and Solarized.
- **Clean Copy & Raw Mode**:
  - Click **Copy** to copy clean YAML source directly to the clipboard (line numbers are excluded from copying).
  - Switch between **Highlighted** and **Raw** view mode at any time.

---

## Architecture

The project consists of:
1. **`YAML QuickLook.app`**: The companion macOS application used for live previewing YAML files, adjusting preferences, and registering extensions with macOS.
2. **`YAMLPreviewExtension.appex`**: Modern Quick Look Preview Extension conforming to `QLPreviewProvider` and `QLPreviewingController`.
3. **`Shared/`**:
   - `YAMLTokenizer.swift`: Fast, streaming YAML tokenizer and fold range calculator.
   - `YAMLValidator.swift`: Syntactic checks for tabs, unclosed quotes, and duplicate keys.
   - `YAMLHTMLRenderer.swift`: Self-contained HTML/CSS/JS generator with zero external network dependencies.
   - `YAMLPreferences.swift`: User configuration management via `UserDefaults`.
   - `YAMLTheme.swift`: Syntax themes.

---

## How to View in DEVONthink

1. **Install and Register**:
   Ensure `YAML QuickLook.app` is placed in `/Applications` (already installed and registered):
   ```bash
   make register
   ```
2. **Open DEVONthink**:
   - Select any `.yaml` or `.yml` file in your database.
   - The preview pane in DEVONthink uses macOS `QLPreviewView` and will automatically render the syntax-highlighted YAML view.
3. **Full Quick Look in DEVONthink**:
   - Select the YAML document and press <kbd>Space</kbd>.
   - The interactive QuickLook window opens with code folding, metadata header, copy button, and soft wrap toggle.
4. **Soft Wrapping in Raw Mode**:
   - In the Quick Look toolbar, click **Raw** to switch to raw text mode.
   - Click the **Wrap** button (or check `Soft Wrap in Raw Mode` in settings) to wrap long lines without horizontal scrollbars.

---

## System Settings (Extensions)

If macOS does not automatically enable the extension:
1. Open **System Settings** > **General** > **Login Items & Extensions**.
2. Scroll down to the **Quick Look** section.
3. Ensure **YAML Previewer** is toggled **ON**.

Alternatively, run:
```bash
pluginkit -e use -i com.2b3pro.qlyaml.preview
qlmanage -r && qlmanage -r cache
```

---

## Build & Test Commands

```bash
# Run the unit test suite
make test

# Build the app and extensions
make build

# Install to /Applications and register with macOS
make install
make register
make restart-ql
```
