import Foundation

public struct YAMLLineToken {
    public let lineNumber: Int
    public let rawText: String
    public let indentLevel: Int
    public let isBlank: Bool
    public let isCommentOnly: Bool
    public let isFoldableHeader: Bool
    public var foldEndLine: Int? // If foldable, the last line included in this fold
    public let htmlContent: String
    public let diagnostic: YAMLDiagnostic?
}

public struct YAMLDiagnostic: Equatable {
    public enum Severity: String {
        case error
        case warning
        case info
    }
    
    public let severity: Severity
    public let line: Int
    public let column: Int
    public let message: String
}

public struct YAMLDocumentAnalysis {
    public let totalLines: Int
    public let totalKeys: Int
    public let documentCount: Int
    public let diagnostics: [YAMLDiagnostic]
    public let lines: [YAMLLineToken]
    
    public var isValid: Bool {
        !diagnostics.contains { $0.severity == .error }
    }
}

public final class YAMLTokenizer {
    public init() {}
    
    public func tokenizeAndAnalyze(_ yamlString: String) -> YAMLDocumentAnalysis {
        let rawLines = yamlString.components(separatedBy: .newlines)
        var parsedLines: [(lineNum: Int, raw: String, indent: Int, isBlank: Bool, isCommentOnly: Bool, isHeader: Bool, html: String, diag: YAMLDiagnostic?)] = []
        var diagnostics: [YAMLDiagnostic] = []
        
        var inBlockScalar = false
        var blockScalarIndent = 0
        var totalKeys = 0
        var separatorCount = 0
        var hadContentBeforeFirstSeparator = false
        var seenFirstSeparator = false
        
        // Pass 1: Line by line tokenization and syntax check
        for (index, line) in rawLines.enumerated() {
            let lineNum = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for tab indentation error (YAML 1.2 spec section 6.1: tabs forbidden for indentation)
            var lineDiag: YAMLDiagnostic? = nil
            let leadingWhitespace = line.prefix(while: { $0 == " " || $0 == "\t" })
            if let tabIndex = leadingWhitespace.firstIndex(of: "\t") {
                let col = line.distance(from: line.startIndex, to: tabIndex) + 1
                let diag = YAMLDiagnostic(
                    severity: .error,
                    line: lineNum,
                    column: col,
                    message: "YAML forbids tab characters for indentation (use spaces)"
                )
                diagnostics.append(diag)
                lineDiag = diag
            }
            
            // Count document markers
            if trimmed == "---" {
                separatorCount += 1
                seenFirstSeparator = true
                inBlockScalar = false
                let html = "<span class=\"hl-doc\">---</span>"
                parsedLines.append((lineNum, line, 0, false, false, false, html, lineDiag))
                continue
            }
            if trimmed == "..." {
                inBlockScalar = false
                let html = "<span class=\"hl-doc\">...</span>"
                parsedLines.append((lineNum, line, 0, false, false, false, html, lineDiag))
                continue
            }
            
            if trimmed.isEmpty {
                parsedLines.append((lineNum, line, 0, true, false, false, "", lineDiag))
                continue
            }
            
            if !trimmed.hasPrefix("#") && !trimmed.hasPrefix("%") {
                if !seenFirstSeparator {
                    hadContentBeforeFirstSeparator = true
                }
            }
            
            let indent = line.prefix(while: { $0 == " " }).count
            
            // Check if we are inside a multi-line block scalar (| or >)
            if inBlockScalar {
                if indent > blockScalarIndent {
                    let escaped = escapeHTML(line)
                    let html = "<span class=\"hl-string hl-scalar-block\">\(escaped)</span>"
                    parsedLines.append((lineNum, line, indent, false, false, false, html, lineDiag))
                    continue
                } else {
                    inBlockScalar = false
                }
            }
            
            // Directives
            if trimmed.hasPrefix("%") {
                let escaped = escapeHTML(line)
                let html = "<span class=\"hl-directive\">\(escaped)</span>"
                parsedLines.append((lineNum, line, indent, false, false, false, html, lineDiag))
                continue
            }
            
            // Comment only line
            if trimmed.hasPrefix("#") {
                let escaped = escapeHTML(line)
                let html = "<span class=\"hl-comment\">\(escaped)</span>"
                parsedLines.append((lineNum, line, indent, false, true, false, html, lineDiag))
                continue
            }
            
            // Highlight regular line
            let (html, keyFound, startsBlock) = highlightYAMLLine(line, indent: indent)
            if keyFound {
                totalKeys += 1
            }
            if startsBlock {
                inBlockScalar = true
                blockScalarIndent = indent
            }
            
            parsedLines.append((lineNum, line, indent, false, false, false, html, lineDiag))
        }
        
        // Pass 2: Calculate code folding ranges based on indentation hierarchy
        var resultTokens: [YAMLLineToken] = []
        let count = parsedLines.count
        
        for i in 0..<count {
            let current = parsedLines[i]
            if current.isBlank || current.isCommentOnly {
                resultTokens.append(YAMLLineToken(
                    lineNumber: current.lineNum,
                    rawText: current.raw,
                    indentLevel: current.indent,
                    isBlank: current.isBlank,
                    isCommentOnly: current.isCommentOnly,
                    isFoldableHeader: false,
                    foldEndLine: nil,
                    htmlContent: current.html,
                    diagnostic: current.diag
                ))
                continue
            }
            
            // Look ahead to see if subsequent lines have deeper indentation
            var isFoldable = false
            var foldEnd = current.lineNum
            var j = i + 1
            
            // Skip trailing empty/comment lines right below header
            while j < count && parsedLines[j].isBlank {
                j += 1
            }
            
            if j < count && parsedLines[j].indent > current.indent {
                isFoldable = true
                var lastValid = j
                while j < count {
                    let next = parsedLines[j]
                    if !next.isBlank && next.indent <= current.indent {
                        break
                    }
                    if !next.isBlank {
                        lastValid = j
                    }
                    j += 1
                }
                foldEnd = parsedLines[lastValid].lineNum
            }
            
            // Only fold if there is more than 1 line to fold
            let canFold = isFoldable && foldEnd > current.lineNum
            
            resultTokens.append(YAMLLineToken(
                lineNumber: current.lineNum,
                rawText: current.raw,
                indentLevel: current.indent,
                isBlank: current.isBlank,
                isCommentOnly: current.isCommentOnly,
                isFoldableHeader: canFold,
                foldEndLine: canFold ? foldEnd : nil,
                htmlContent: current.html,
                diagnostic: current.diag
            ))
        }
        
        let totalDocs = hadContentBeforeFirstSeparator ? (separatorCount + 1) : max(1, separatorCount)
        return YAMLDocumentAnalysis(
            totalLines: rawLines.count,
            totalKeys: totalKeys,
            documentCount: totalDocs,
            diagnostics: diagnostics,
            lines: resultTokens
        )
    }
    
    private func highlightYAMLLine(_ line: String, indent: Int) -> (html: String, hasKey: Bool, startsBlockScalar: Bool) {
        var html = ""
        let leadingSpaces = String(repeating: " ", count: indent)
        html += leadingSpaces
        
        let content = String(line.dropFirst(indent))
        var remainder = content[...]
        var hasKey = false
        var startsBlock = false
        
        // Check for sequence indicator: "- " or "-" at end of line
        if remainder.hasPrefix("- ") {
            html += "<span class=\"hl-bullet\">- </span>"
            remainder = remainder.dropFirst(2)
        } else if remainder == "-" {
            html += "<span class=\"hl-bullet\">-</span>"
            remainder = remainder.dropFirst(1)
        }
        
        // Skip whitespace after bullet
        let afterBulletSpaces = remainder.prefix(while: { $0 == " " })
        if !afterBulletSpaces.isEmpty {
            html += afterBulletSpaces
            remainder = remainder.dropFirst(afterBulletSpaces.count)
        }
        
        // Look for inline comment
        var inlineComment: Substring? = nil
        if let commentIndex = findCommentIndex(in: remainder) {
            inlineComment = remainder[commentIndex...]
            remainder = remainder[..<commentIndex]
        }
        
        // Look for Mapping Key: "key: " or "key:\n"
        if let colonIndex = findMappingKey(in: remainder) {
            hasKey = true
            let keyPart = remainder[..<colonIndex]
            let afterColon = remainder[remainder.index(after: colonIndex)...]
            
            html += "<span class=\"hl-key\">\(escapeHTML(String(keyPart)))</span><span class=\"hl-punct\">:</span>"
            
            // Highlight value part
            let valueHighlighted = highlightValue(String(afterColon), startsBlockScalar: &startsBlock)
            html += valueHighlighted
        } else {
            // Not a mapping key - highlight as value/scalar/anchor/etc.
            let valueHighlighted = highlightValue(String(remainder), startsBlockScalar: &startsBlock)
            html += valueHighlighted
        }
        
        if let comment = inlineComment {
            html += "<span class=\"hl-comment\">\(escapeHTML(String(comment)))</span>"
        }
        
        return (html, hasKey, startsBlock)
    }
    
    private func findMappingKey(in text: Substring) -> Substring.Index? {
        if text.isEmpty { return nil }
        
        var inQuote: Character? = nil
        var index = text.startIndex
        
        while index < text.endIndex {
            let char = text[index]
            
            if let quote = inQuote {
                if char == "\\" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex {
                        index = text.index(after: nextIndex)
                        continue
                    }
                } else if char == quote {
                    inQuote = nil
                }
            } else {
                if char == "\"" || char == "'" {
                    inQuote = char
                } else if char == ":" {
                    let nextIndex = text.index(after: index)
                    if nextIndex == text.endIndex || text[nextIndex] == " " || text[nextIndex] == "\t" {
                        return index
                    }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }
    
    private func findCommentIndex(in text: Substring) -> Substring.Index? {
        var inQuote: Character? = nil
        var index = text.startIndex
        
        while index < text.endIndex {
            let char = text[index]
            
            if let quote = inQuote {
                if char == "\\" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex {
                        index = text.index(after: nextIndex)
                        continue
                    }
                } else if char == quote {
                    inQuote = nil
                }
            } else {
                if char == "\"" || char == "'" {
                    inQuote = char
                } else if char == "#" {
                    // In YAML, # must be preceded by whitespace or at the start
                    if index == text.startIndex {
                        return index
                    }
                    let prevIndex = text.index(before: index)
                    if text[prevIndex] == " " || text[prevIndex] == "\t" {
                        return index
                    }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }
    
    private func highlightValue(_ val: String, startsBlockScalar: inout Bool) -> String {
        let spacesPrefix = val.prefix(while: { $0 == " " || $0 == "\t" })
        let core = String(val.dropFirst(spacesPrefix.count))
        
        if core.isEmpty {
            return String(spacesPrefix)
        }
        
        var result = String(spacesPrefix)
        let trimmed = core.trimmingCharacters(in: .whitespaces)
        
        // Multi-line block scalar indicator: |, |-, |+, >, >-, >+
        if trimmed.hasPrefix("|") || trimmed.hasPrefix(">") {
            startsBlockScalar = true
            result += "<span class=\"hl-scalar-header\">\(escapeHTML(core))</span>"
            return result
        }
        
        // Tag indicator: !tag or !!tag
        if trimmed.hasPrefix("!") {
            let parts = core.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count > 0 {
                result += "<span class=\"hl-tag\">\(escapeHTML(String(parts[0])))</span>"
                if parts.count > 1 {
                    result += " "
                    var subBlock = false
                    result += highlightValue(String(parts[1]), startsBlockScalar: &subBlock)
                }
                return result
            }
        }
        
        // Anchor: &anchor
        if trimmed.hasPrefix("&") {
            let parts = core.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            result += "<span class=\"hl-anchor\">\(escapeHTML(String(parts[0])))</span>"
            if parts.count > 1 {
                result += " "
                var subBlock = false
                result += highlightValue(String(parts[1]), startsBlockScalar: &subBlock)
            }
            return result
        }
        
        // Alias: *alias
        if trimmed.hasPrefix("*") {
            result += "<span class=\"hl-alias\">\(escapeHTML(core))</span>"
            return result
        }
        
        // Merge key: <<
        if trimmed == "<<" {
            result += "<span class=\"hl-alias\">&lt;&lt;</span>"
            return result
        }
        
        // Booleans
        let lower = trimmed.lowercased()
        if ["true", "false", "yes", "no", "on", "off"].contains(lower) {
            result += "<span class=\"hl-bool\">\(escapeHTML(core))</span>"
            return result
        }
        
        // Null
        if ["null", "~", "nil"].contains(lower) {
            result += "<span class=\"hl-null\">\(escapeHTML(core))</span>"
            return result
        }
        
        // Date / Timestamp (e.g. 2026-09-17 or 2026-09-17T16:14:15Z)
        if isDateOrTimestamp(trimmed) {
            result += "<span class=\"hl-date\">\(escapeHTML(core))</span>"
            return result
        }
        
        // Numbers: int, hex, oct, float, .nan, .inf
        if isNumeric(trimmed) {
            result += "<span class=\"hl-number\">\(escapeHTML(core))</span>"
            return result
        }
        
        // Double quoted string
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2 {
            result += "<span class=\"hl-string\">\(escapeHTML(core))</span>"
            return result
        }
        
        // Single quoted string
        if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2 {
            result += "<span class=\"hl-string\">\(escapeHTML(core))</span>"
            return result
        }
        
        // Flow collections: [ ... ] or { ... }
        if (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) || (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) {
            result += "<span class=\"hl-flow\">\(escapeHTML(core))</span>"
            return result
        }
        
        // Default plain scalar string
        result += "<span class=\"hl-scalar\">\(escapeHTML(core))</span>"
        return result
    }
    
    private func isNumeric(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower == ".nan" || lower == ".inf" || lower == "+.inf" || lower == "-.inf" {
            return true
        }
        if lower.hasPrefix("0x") && Int(text.dropFirst(2), radix: 16) != nil {
            return true
        }
        if lower.hasPrefix("0o") && Int(text.dropFirst(2), radix: 8) != nil {
            return true
        }
        if Double(text) != nil {
            return true
        }
        return false
    }
    
    private func isDateOrTimestamp(_ text: String) -> Bool {
        // Simple regex-like match for YYYY-MM-DD
        let pattern = #"^\d{4}-\d{2}-\d{2}([ T]\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?)?$"#
        return text.range(of: pattern, options: .regularExpression) != nil
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
