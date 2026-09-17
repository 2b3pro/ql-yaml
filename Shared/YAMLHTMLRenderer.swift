import Foundation

public final class YAMLHTMLRenderer {
    private let tokenizer = YAMLTokenizer()
    private let validator = YAMLValidator()
    
    public init() {}
    
    public func render(
        yamlString: String,
        fileName: String = "document.yaml",
        fileSizeBytes: Int64 = 0,
        preferences: YAMLPreferences = .shared
    ) -> String {
        let analysis = tokenizer.tokenizeAndAnalyze(yamlString)
        let extraDiagnostics = validator.validate(yamlString)
        
        // Merge diagnostics
        var allDiagnostics = analysis.diagnostics
        for diag in extraDiagnostics {
            if !allDiagnostics.contains(where: { $0.line == diag.line && $0.message == diag.message }) {
                allDiagnostics.append(diag)
            }
        }
        allDiagnostics.sort { $0.line < $1.line }
        
        let firstError = allDiagnostics.first(where: { $0.severity == .error })
        let firstWarning = allDiagnostics.first(where: { $0.severity == .warning })
        
        let formattedSize = ByteCountFormatter.string(fromByteCount: fileSizeBytes > 0 ? fileSizeBytes : Int64(yamlString.utf8.count), countStyle: .file)
        
        let showGutter = preferences.showLineNumbers
        let enableFolding = preferences.enableFolding
        let showHeader = preferences.showHeader
        let fontSize = preferences.fontSize
        let softWrapRaw = preferences.softWrapRaw
        
        var linesHTML = ""
        for token in analysis.lines {
            let lineNum = token.lineNumber
            let hasError = allDiagnostics.contains(where: { $0.line == lineNum && $0.severity == .error })
            let hasWarning = allDiagnostics.contains(where: { $0.line == lineNum && $0.severity == .warning })
            
            var lineClasses = ["code-line"]
            if hasError { lineClasses.append("line-error") }
            else if hasWarning { lineClasses.append("line-warning") }
            if token.isBlank { lineClasses.append("line-blank") }
            
            let foldAttrs: String
            if enableFolding && token.isFoldableHeader, let endLine = token.foldEndLine {
                lineClasses.append("foldable")
                foldAttrs = " data-fold-start=\"\(lineNum)\" data-fold-end=\"\(endLine)\""
            } else {
                foldAttrs = ""
            }
            
            let lineClassStr = lineClasses.joined(separator: " ")
            
            linesHTML += "<div id=\"L\(lineNum)\" class=\"\(lineClassStr)\" data-line=\"\(lineNum)\"\(foldAttrs)>"
            
            if showGutter {
                let foldToggleHTML: String
                if enableFolding && token.isFoldableHeader {
                    foldToggleHTML = "<span class=\"fold-toggle\" onclick=\"toggleFold(\(lineNum))\">▾</span>"
                } else {
                    foldToggleHTML = "<span class=\"fold-spacer\"></span>"
                }
                
                linesHTML += "<div class=\"gutter\">"
                linesHTML += "<span class=\"line-number\" onclick=\"highlightLine(\(lineNum))\">\(lineNum)</span>"
                linesHTML += foldToggleHTML
                linesHTML += "</div>"
            }
            
            let content = token.isBlank ? "&nbsp;" : token.htmlContent
            linesHTML += "<div class=\"line-content\">\(content)</div>"
            
            // If line has a diagnostic, show an inline badge
            if let diag = allDiagnostics.first(where: { $0.line == lineNum }) {
                let badgeClass = diag.severity == .error ? "diag-error" : "diag-warning"
                linesHTML += "<div class=\"inline-diag \(badgeClass)\">\(escapeHTML(diag.message))</div>"
            }
            
            linesHTML += "</div>\n"
        }
        
        let statusBadgeHTML: String
        if let err = firstError {
            statusBadgeHTML = "<span class=\"badge badge-error\" onclick=\"scrollToLine(\(err.line))\" title=\"Click to jump to line \(err.line)\">⚠ Error (Line \(err.line))</span>"
        } else if let warn = firstWarning {
            statusBadgeHTML = "<span class=\"badge badge-warning\" onclick=\"scrollToLine(\(warn.line))\" title=\"Click to jump to line \(warn.line)\">⚠ Warning (Line \(warn.line))</span>"
        } else {
            let docStr = analysis.documentCount > 1 ? "\(analysis.documentCount) Docs" : "YAML"
            statusBadgeHTML = "<span class=\"badge badge-success\">✓ Valid \(docStr)</span>"
        }
        
        let headerHTML: String
        if showHeader {
            headerHTML = """
            <header class="toolbar">
                <div class="toolbar-left">
                    <div class="file-icon">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                            <polyline points="14 2 14 8 20 8"></polyline>
                            <line x1="16" y1="13" x2="8" y2="13"></line>
                            <line x1="16" y1="17" x2="8" y2="17"></line>
                            <polyline points="10 9 9 9 8 9"></polyline>
                        </svg>
                    </div>
                    <span class="file-name">\(escapeHTML(fileName))</span>
                    <span class="file-meta">\(formattedSize) • \(analysis.totalLines) lines</span>
                    \(statusBadgeHTML)
                </div>
                <div class="toolbar-right">
                    \(enableFolding ? "<button class=\"btn\" onclick=\"expandAll()\">Expand All</button><button class=\"btn\" onclick=\"collapseAll()\">Collapse All</button>" : "")
                    <button id=\"btn-view-mode\" class=\"btn\" onclick=\"toggleRawMode()\">Raw</button>
                    <button id=\"btn-wrap\" class=\"btn\" onclick=\"toggleWrap()\" title=\"Toggle Soft Wrap of lines\">Wrap</button>
                    <button id=\"btn-copy\" class=\"btn btn-primary\" onclick=\"copyRawContent()\">Copy</button>
                </div>
            </header>
            """
        } else {
            headerHTML = ""
        }
        
        let escapedRawYAML = escapeHTML(yamlString)
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(fileName))</title>
            <style>
                :root {
                    --font-size: \(fontSize)px;
                    --line-height: 1.55;
                    --font-family: ui-monospace, "SF Mono", Menlo, Monaco, "Cascadia Code", "Source Code Pro", Consolas, monospace;
                    
                    /* Light Mode Palette */
                    --bg: #ffffff;
                    --bg-alt: #f8fafc;
                    --toolbar-bg: rgba(255, 255, 255, 0.85);
                    --toolbar-border: #e2e8f0;
                    --text: #1e293b;
                    --gutter-bg: #f8fafc;
                    --gutter-text: #94a3b8;
                    --gutter-border: #e2e8f0;
                    --line-highlight: rgba(59, 130, 246, 0.08);
                    --line-error-bg: rgba(239, 68, 68, 0.12);
                    --line-warning-bg: rgba(245, 158, 11, 0.12);
                    --btn-bg: #f1f5f9;
                    --btn-border: #cbd5e1;
                    --btn-text: #334155;
                    --btn-hover: #e2e8f0;
                    --btn-primary-bg: #2563eb;
                    --btn-primary-text: #ffffff;
                    --badge-success-bg: #dcfce7;
                    --badge-success-text: #166534;
                    --badge-error-bg: #fee2e2;
                    --badge-error-text: #991b1b;
                    --badge-warning-bg: #fef3c7;
                    --badge-warning-text: #92400e;
                    
                    /* Syntax Colors (Light) */
                    --hl-key: #0284c7;
                    --hl-punct: #64748b;
                    --hl-string: #15803d;
                    --hl-number: #dc2626;
                    --hl-bool: #d97706;
                    --hl-null: #b45309;
                    --hl-date: #0891b2;
                    --hl-comment: #94a3b8;
                    --hl-doc: #7c3aed;
                    --hl-tag: #4f46e5;
                    --hl-anchor: #9333ea;
                    --hl-alias: #a855f7;
                    --hl-bullet: #0284c7;
                    --hl-scalar: #1e293b;
                    --hl-scalar-header: #ea580c;
                    --hl-scalar-block: #166534;
                }
                
                @media (prefers-color-scheme: dark) {
                    :root {
                        /* Dark Mode Palette */
                        --bg: #0f172a;
                        --bg-alt: #1e293b;
                        --toolbar-bg: rgba(15, 23, 42, 0.88);
                        --toolbar-border: #334155;
                        --text: #f1f5f9;
                        --gutter-bg: #0f172a;
                        --gutter-text: #64748b;
                        --gutter-border: #334155;
                        --line-highlight: rgba(56, 189, 248, 0.12);
                        --line-error-bg: rgba(239, 68, 68, 0.2);
                        --line-warning-bg: rgba(245, 158, 11, 0.2);
                        --btn-bg: #1e293b;
                        --btn-border: #475569;
                        --btn-text: #cbd5e1;
                        --btn-hover: #334155;
                        --btn-primary-bg: #38bdf8;
                        --btn-primary-text: #0f172a;
                        --badge-success-bg: rgba(34, 197, 94, 0.2);
                        --badge-success-text: #4ade80;
                        --badge-error-bg: rgba(239, 68, 68, 0.25);
                        --badge-error-text: #f87171;
                        --badge-warning-bg: rgba(245, 158, 11, 0.25);
                        --badge-warning-text: #fbbf24;
                        
                        /* Syntax Colors (Dark) */
                        --hl-key: #38bdf8;
                        --hl-punct: #94a3b8;
                        --hl-string: #4ade80;
                        --hl-number: #f87171;
                        --hl-bool: #fb923c;
                        --hl-null: #facc15;
                        --hl-date: #22d3ee;
                        --hl-comment: #64748b;
                        --hl-doc: #c084fc;
                        --hl-tag: #818cf8;
                        --hl-anchor: #c084fc;
                        --hl-alias: #e879f9;
                        --hl-bullet: #38bdf8;
                        --hl-scalar: #f1f5f9;
                        --hl-scalar-header: #fb923c;
                        --hl-scalar-block: #86efac;
                    }
                }
                
                * {
                    box-sizing: border-box;
                    margin: 0;
                    padding: 0;
                }
                
                body {
                    background-color: var(--bg);
                    color: var(--text);
                    font-family: var(--font-family);
                    font-size: var(--font-size);
                    line-height: var(--line-height);
                    -webkit-font-smoothing: antialiased;
                    -moz-osx-font-smoothing: grayscale;
                    overflow-x: auto;
                }
                
                .toolbar {
                    position: sticky;
                    top: 0;
                    z-index: 100;
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 8px 16px;
                    background: var(--toolbar-bg);
                    backdrop-filter: blur(12px);
                    -webkit-backdrop-filter: blur(12px);
                    border-bottom: 1px solid var(--toolbar-border);
                    user-select: none;
                }
                
                .toolbar-left, .toolbar-right {
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }
                
                .file-icon {
                    display: flex;
                    align-items: center;
                    color: var(--hl-key);
                }
                
                .file-name {
                    font-weight: 600;
                    font-size: 13px;
                    color: var(--text);
                }
                
                .file-meta {
                    font-size: 12px;
                    color: var(--gutter-text);
                }
                
                .badge {
                    display: inline-flex;
                    align-items: center;
                    padding: 2px 8px;
                    border-radius: 9999px;
                    font-size: 11px;
                    font-weight: 500;
                    cursor: pointer;
                    transition: opacity 0.15s ease;
                }
                .badge:hover {
                    opacity: 0.85;
                }
                .badge-success {
                    background-color: var(--badge-success-bg);
                    color: var(--badge-success-text);
                    cursor: default;
                }
                .badge-error {
                    background-color: var(--badge-error-bg);
                    color: var(--badge-error-text);
                }
                .badge-warning {
                    background-color: var(--badge-warning-bg);
                    color: var(--badge-warning-text);
                }
                
                .btn {
                    padding: 4px 10px;
                    font-size: 12px;
                    font-weight: 500;
                    font-family: inherit;
                    color: var(--btn-text);
                    background-color: var(--btn-bg);
                    border: 1px solid var(--btn-border);
                    border-radius: 6px;
                    cursor: pointer;
                    transition: all 0.15s ease;
                }
                .btn:hover {
                    background-color: var(--btn-hover);
                }
                .btn-primary {
                    background-color: var(--btn-primary-bg);
                    border-color: var(--btn-primary-bg);
                    color: var(--btn-primary-text);
                }
                .btn-primary:hover {
                    opacity: 0.9;
                }
                .btn.btn-active {
                    background-color: var(--line-highlight);
                    border-color: var(--hl-key);
                    color: var(--hl-key);
                    font-weight: 600;
                }
                
                #code-container {
                    padding: 12px 0 32px 0;
                    white-space: pre;
                    tab-size: 2;
                }
                #code-container.wrap {
                    white-space: normal;
                }
                #code-container.wrap .line-content {
                    white-space: pre-wrap;
                    word-break: break-word;
                    overflow-wrap: break-word;
                }
                
                .code-line {
                    display: flex;
                    min-height: calc(var(--font-size) * var(--line-height));
                    transition: background-color 0.1s ease;
                }
                .code-line:hover {
                    background-color: var(--line-highlight);
                }
                .code-line.line-selected {
                    background-color: var(--line-highlight);
                }
                .code-line.line-error {
                    background-color: var(--line-error-bg);
                    border-left: 3px solid #ef4444;
                }
                .code-line.line-warning {
                    background-color: var(--line-warning-bg);
                    border-left: 3px solid #f59e0b;
                }
                
                .gutter {
                    flex-shrink: 0;
                    width: 60px;
                    display: flex;
                    align-items: center;
                    justify-content: flex-end;
                    padding-right: 12px;
                    user-select: none;
                    -webkit-user-select: none;
                    color: var(--gutter-text);
                    background: var(--gutter-bg);
                    border-right: 1px solid var(--gutter-border);
                    margin-right: 14px;
                }
                
                .line-number {
                    cursor: pointer;
                    font-size: 12px;
                    text-align: right;
                }
                .line-number:hover {
                    color: var(--text);
                }
                
                .fold-toggle {
                    width: 14px;
                    text-align: center;
                    cursor: pointer;
                    margin-left: 4px;
                    font-size: 11px;
                    color: var(--gutter-text);
                    transition: transform 0.15s ease, color 0.15s ease;
                }
                .fold-toggle:hover {
                    color: var(--hl-key);
                }
                .fold-spacer {
                    width: 14px;
                    margin-left: 4px;
                }
                
                .line-content {
                    flex-grow: 1;
                    padding-right: 16px;
                }
                
                .folded-placeholder {
                    display: inline-block;
                    margin-left: 8px;
                    padding: 0 6px;
                    font-size: 11px;
                    border-radius: 4px;
                    background: var(--btn-bg);
                    border: 1px solid var(--btn-border);
                    color: var(--gutter-text);
                    cursor: pointer;
                    user-select: none;
                }
                .folded-placeholder:hover {
                    color: var(--text);
                    background: var(--btn-hover);
                }
                
                .inline-diag {
                    margin-left: 12px;
                    padding: 1px 8px;
                    border-radius: 4px;
                    font-size: 11px;
                    font-weight: 500;
                    display: inline-flex;
                    align-items: center;
                }
                .diag-error {
                    background: var(--badge-error-bg);
                    color: var(--badge-error-text);
                }
                .diag-warning {
                    background: var(--badge-warning-bg);
                    color: var(--badge-warning-text);
                }
                
                /* Syntax Highlighting */
                .hl-key { color: var(--hl-key); font-weight: 600; }
                .hl-punct { color: var(--hl-punct); }
                .hl-string { color: var(--hl-string); }
                .hl-number { color: var(--hl-number); font-weight: 500; }
                .hl-bool { color: var(--hl-bool); font-weight: 600; }
                .hl-null { color: var(--hl-null); font-weight: 600; }
                .hl-date { color: var(--hl-date); }
                .hl-comment { color: var(--hl-comment); font-style: italic; }
                .hl-doc { color: var(--hl-doc); font-weight: 700; }
                .hl-directive { color: var(--hl-doc); font-weight: 600; }
                .hl-tag { color: var(--hl-tag); font-weight: 600; }
                .hl-anchor { color: var(--hl-anchor); font-weight: 600; }
                .hl-alias { color: var(--hl-alias); font-style: italic; }
                .hl-bullet { color: var(--hl-bullet); font-weight: 700; }
                .hl-scalar { color: var(--hl-scalar); }
                .hl-scalar-header { color: var(--hl-scalar-header); font-weight: 700; }
                .hl-scalar-block { color: var(--hl-scalar-block); }
                .hl-flow { color: var(--hl-punct); }
                
                /* Raw View Mode */
                #raw-container {
                    display: none;
                    padding: 16px;
                    font-family: var(--font-family);
                    font-size: var(--font-size);
                    line-height: var(--line-height);
                    overflow-x: auto;
                }
                #raw-container.wrap {
                    white-space: pre-wrap;
                    word-break: break-word;
                    overflow-wrap: break-word;
                }
                #raw-container.no-wrap {
                    white-space: pre;
                    overflow-x: auto;
                }
            </style>
        </head>
        <body>
            \(headerHTML)
            <div id="code-container">
                \(linesHTML)
            </div>
            <pre id="raw-container">\(escapedRawYAML)</pre>
            
            <script>
                let isRawMode = false;
                const foldedRanges = new Map(); // startLine -> endLine
                
                function toggleFold(lineNum) {
                    const lineEl = document.getElementById("L" + lineNum);
                    if (!lineEl) return;
                    
                    const foldEnd = parseInt(lineEl.getAttribute("data-fold-end"), 10);
                    if (!foldEnd || foldEnd <= lineNum) return;
                    
                    const toggleEl = lineEl.querySelector(".fold-toggle");
                    const isCurrentlyFolded = foldedRanges.has(lineNum);
                    
                    if (isCurrentlyFolded) {
                        // Unfold
                        foldedRanges.delete(lineNum);
                        if (toggleEl) toggleEl.textContent = "▾";
                        
                        const placeholder = lineEl.querySelector(".folded-placeholder");
                        if (placeholder) placeholder.remove();
                        
                        for (let l = lineNum + 1; l <= foldEnd; l++) {
                            const child = document.getElementById("L" + l);
                            if (child) child.style.display = "";
                        }
                    } else {
                        // Fold
                        foldedRanges.set(lineNum, foldEnd);
                        if (toggleEl) toggleEl.textContent = "▸";
                        
                        let hiddenCount = foldEnd - lineNum;
                        let placeholder = lineEl.querySelector(".folded-placeholder");
                        if (!placeholder) {
                            placeholder = document.createElement("span");
                            placeholder.className = "folded-placeholder";
                            placeholder.textContent = "··· {" + hiddenCount + " lines} ···";
                            placeholder.onclick = function(e) { e.stopPropagation(); toggleFold(lineNum); };
                            lineEl.appendChild(placeholder);
                        }
                        
                        for (let l = lineNum + 1; l <= foldEnd; l++) {
                            const child = document.getElementById("L" + l);
                            if (child) child.style.display = "none";
                        }
                    }
                }
                
                function collapseAll() {
                    const foldables = document.querySelectorAll(".code-line.foldable");
                    foldables.forEach(el => {
                        const start = parseInt(el.getAttribute("data-fold-start"), 10);
                        if (start && !foldedRanges.has(start)) {
                            toggleFold(start);
                        }
                    });
                }
                
                function expandAll() {
                    const starts = Array.from(foldedRanges.keys());
                    starts.forEach(start => {
                        toggleFold(start);
                    });
                }
                
                function highlightLine(lineNum) {
                    document.querySelectorAll(".code-line.line-selected").forEach(el => el.classList.remove("line-selected"));
                    const el = document.getElementById("L" + lineNum);
                    if (el) el.classList.add("line-selected");
                }
                
                function scrollToLine(lineNum) {
                    const el = document.getElementById("L" + lineNum);
                    if (el) {
                        el.scrollIntoView({ behavior: "smooth", block: "center" });
                        highlightLine(lineNum);
                    }
                }
                
                function toggleRawMode() {
                    const codeBox = document.getElementById("code-container");
                    const rawBox = document.getElementById("raw-container");
                    const btn = document.getElementById("btn-view-mode");
                    isRawMode = !isRawMode;
                    
                    if (isRawMode) {
                        codeBox.style.display = "none";
                        rawBox.style.display = "block";
                        if (btn) btn.textContent = "Highlighted";
                    } else {
                        codeBox.style.display = "block";
                        rawBox.style.display = "none";
                        if (btn) btn.textContent = "Raw";
                    }
                    applyWrap();
                }
                
                let isWrapped = \(softWrapRaw ? "true" : "false");
                
                function toggleWrap() {
                    isWrapped = !isWrapped;
                    applyWrap();
                }
                
                function applyWrap() {
                    const rawBox = document.getElementById("raw-container");
                    const codeBox = document.getElementById("code-container");
                    const wrapBtn = document.getElementById("btn-wrap");
                    
                    if (isWrapped) {
                        if (rawBox) {
                            rawBox.classList.add("wrap");
                            rawBox.classList.remove("no-wrap");
                        }
                        if (codeBox) {
                            codeBox.classList.add("wrap");
                        }
                        if (wrapBtn) {
                            wrapBtn.classList.add("btn-active");
                            wrapBtn.textContent = "Wrap: On";
                        }
                    } else {
                        if (rawBox) {
                            rawBox.classList.remove("wrap");
                            rawBox.classList.add("no-wrap");
                        }
                        if (codeBox) {
                            codeBox.classList.remove("wrap");
                        }
                        if (wrapBtn) {
                            wrapBtn.classList.remove("btn-active");
                            wrapBtn.textContent = "Wrap: Off";
                        }
                    }
                }
                
                // Initialize wrap state
                applyWrap();
                
                function copyRawContent() {
                    const rawText = document.getElementById("raw-container").textContent;
                    navigator.clipboard.writeText(rawText).then(() => {
                        const btn = document.getElementById("btn-copy");
                        if (btn) {
                            const original = btn.textContent;
                            btn.textContent = "✓ Copied!";
                            setTimeout(() => { btn.textContent = original; }, 2000);
                        }
                    }).catch(err => {
                        console.error("Copy failed", err);
                    });
                }
            </script>
        </body>
        </html>
        """
    }
    
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
