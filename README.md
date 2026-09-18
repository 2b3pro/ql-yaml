# YAML QuickLook for macOS

A modern, fast, and feature-rich Quick Look Preview Extension for viewing YAML (`.yaml`, `.yml`) files in **macOS Finder** and any QuickLook-compatible application.

Built natively with Swift and modern macOS App Extension APIs (`com.apple.quicklook.preview`).

---

## Key Features

- **Seamless macOS Finder Integration**:
  - **Finder Column / Preview Pane**: When a YAML file is selected in Finder, enjoy an interactive, scrollable raw text view right inside the preview column (identical to Markdown and source code files).
  - **Full Quick Look (<kbd>Space</kbd>)**: Press Space on any YAML file to launch the rich interactive viewer with syntax highlighting, code folding, dark mode, and wrapping controls.
  - **Broad Compatibility**: Seamlessly functions in any macOS application that leverages `QLPreviewView` or standard Quick Look APIs (e.g. DEVONthink, Alfred, Raycast, etc.).
- **Soft Line Wrapping (Raw & Highlighted Mode)**:
  - Toggle soft wrapping with a single click using the **Wrap: On / Wrap: Off** toolbar button.
  - In both highlighted and raw view modes, long lines wrap cleanly without horizontal scrolling.
  - Configurable default wrapping behavior in the companion app settings.
- **YAML 1.2 Syntax Highlighting**:
  - Keys, double/single-quoted strings, unquoted scalar values.
  - Numbers (integers, floats, hex `0x`, octal `0o`, `.nan`, `.inf`).
  - Booleans (`true`, `false`, `yes`, `no`, `on`, `off`), nulls (`null`, `~`, `nil`), and ISO dates/timestamps.
  - YAML Anchors (`&anchor`), Aliases (`*anchor`), and merge keys (`<<: *anchor`).
  - Tags (`!include`, `!!str`, `!secret`), multi-line block scalar headers (`|`, `>`).
  - Comments (`# ...`) and document dividers (`---`, `...`).
- **Interactive Code Folding**:
  - Collapsible nested YAML mappings and sequences.
  - Click fold indicators (`▾` / `▸`) to collapse deep structures like Kubernetes manifests, GitHub Actions workflows, or Docker Compose files.
  - Quick **Expand All** and **Collapse All** buttons.
- **YAML Syntax Validation & Error Diagnostics**:
  - Automatically detects YAML syntax issues (forbidden tab characters in indentation, unclosed quotes, duplicate dictionary keys).
  - Displays a green `✓ Valid YAML` badge or a red `⚠ Error / Warning` badge in the header.
  - Clicking the badge scrolls and jumps directly to the offending line.
- **Appearance & Dark/Light Mode**:
  - Automatically matches system dark/light appearance via `@media (prefers-color-scheme: dark)`.
  - Multiple built-in color themes: System Adaptive, Xcode, GitHub, Monokai, Dracula, and Solarized.
- **Clean Copy & Raw Mode**:
  - Click **Copy** to copy clean YAML source directly to the clipboard (line numbers are excluded from copying).
  - Switch between **Highlighted** and **Raw** view mode at any time.

---

## Installation

### Option 1: Download Release (Recommended)
1. Download the latest `YAML-QuickLook-v1.0.0.dmg` from the [Releases](https://github.com/2b3pro/ql-yaml/releases) page.
2. Drag **YAML QuickLook.app** into your `/Applications` folder.
3. Launch the app once to register the Quick Look extension with macOS.
4. Select any `.yaml` or `.yml` file in Finder and press <kbd>Space</kbd>!

### Option 2: Build from Source
```bash
git clone https://github.com/2b3pro/ql-yaml.git
cd ql-yaml
make build
make install
make register
make restart-ql
```

---

## System Settings (Extensions)

If macOS does not automatically enable the extension:
1. Open **System Settings** > **General** > **Login Items & Extensions**.
2. Scroll down to the **Quick Look** section.
3. Ensure **YAML Previewer** is toggled **ON**.

Alternatively, run from Terminal:
```bash
pluginkit -e use -i com.2b3pro.qlyaml.preview
qlmanage -r && qlmanage -r cache
```

---

## Architecture

The project consists of:
1. **`YAML QuickLook.app`**: Native macOS companion application for live previewing YAML files, customizing preferences, and registering extensions with macOS.
2. **`YAMLPreviewExtension.appex`**: Modern Quick Look Preview Extension conforming to `QLPreviewProvider` and `QLPreviewingController`.
3. **`Shared/`**:
   - `YAMLTokenizer.swift`: Fast, streaming YAML tokenizer and fold range calculator.
   - `YAMLValidator.swift`: Syntactic checks for tabs, unclosed quotes, and duplicate keys.
   - `YAMLHTMLRenderer.swift`: Self-contained HTML/CSS/JS generator with zero external network dependencies.
   - `YAMLPreferences.swift`: User configuration management via `UserDefaults`.
   - `YAMLTheme.swift`: Syntax themes.

---

## License

This project is licensed under the [MIT License](LICENSE).
