import Foundation

public final class YAMLValidator {
    public init() {}
    
    public func validate(_ yamlString: String) -> [YAMLDiagnostic] {
        var diagnostics: [YAMLDiagnostic] = []
        let rawLines = yamlString.components(separatedBy: .newlines)
        
        // Track keys per indentation level: [IndentLevel: Set<Key>]
        var levelKeys: [Int: Set<String>] = [:]
        var prevIndent = 0
        var inBlockScalar = false
        var blockScalarIndent = 0
        
        for (index, line) in rawLines.enumerated() {
            let lineNum = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Document separators reset keys
            if trimmed == "---" || trimmed == "..." {
                levelKeys.removeAll()
                prevIndent = 0
                inBlockScalar = false
                continue
            }
            
            // Check for tab indentation
            let leadingWhitespace = line.prefix(while: { $0 == " " || $0 == "\t" })
            if let tabIndex = leadingWhitespace.firstIndex(of: "\t") {
                let col = line.distance(from: line.startIndex, to: tabIndex) + 1
                diagnostics.append(YAMLDiagnostic(
                    severity: .error,
                    line: lineNum,
                    column: col,
                    message: "YAML forbids tab characters for indentation (use spaces)"
                ))
            }
            
            let indent = line.prefix(while: { $0 == " " }).count
            
            if inBlockScalar {
                if indent > blockScalarIndent {
                    continue
                } else {
                    inBlockScalar = false
                }
            }
            
            // Check for block scalar start
            if trimmed.hasSuffix(": |") || trimmed.hasSuffix(": >") || trimmed.hasSuffix(": |-") || trimmed.hasSuffix(": >-") {
                inBlockScalar = true
                blockScalarIndent = indent
            }
            
            // Check for unclosed quotes
            if let quoteError = checkUnclosedQuotes(in: trimmed) {
                diagnostics.append(YAMLDiagnostic(
                    severity: .error,
                    line: lineNum,
                    column: quoteError.column,
                    message: quoteError.message
                ))
            }
            
            // Clear deeper level keys when indent decreases
            if indent < prevIndent {
                for key in levelKeys.keys where key > indent {
                    levelKeys.removeValue(forKey: key)
                }
            }
            prevIndent = indent
            
            // Check for duplicate keys at current level
            if let key = extractMappingKey(from: trimmed) {
                if levelKeys[indent] == nil {
                    levelKeys[indent] = Set<String>()
                }
                if levelKeys[indent]?.contains(key) == true {
                    diagnostics.append(YAMLDiagnostic(
                        severity: .warning,
                        line: lineNum,
                        column: indent + 1,
                        message: "Duplicate key \"\(key)\" at the same indentation level"
                    ))
                } else {
                    levelKeys[indent]?.insert(key)
                }
            }
        }
        
        return diagnostics
    }
    
    private func checkUnclosedQuotes(in text: String) -> (column: Int, message: String)? {
        var inDouble = false
        var inSingle = false
        var escaped = false
        var doubleStartCol = 0
        var singleStartCol = 0
        
        for (idx, char) in text.enumerated() {
            let col = idx + 1
            if char == "#" && !inDouble && !inSingle {
                // Ignore comments
                break
            }
            
            if escaped {
                escaped = false
                continue
            }
            
            if char == "\\" && inDouble {
                escaped = true
                continue
            }
            
            if char == "\"" && !inSingle {
                inDouble.toggle()
                if inDouble { doubleStartCol = col }
            } else if char == "'" && !inDouble {
                inSingle.toggle()
                if inSingle { singleStartCol = col }
            }
        }
        
        if inDouble {
            return (doubleStartCol, "Unclosed double quote (\")")
        }
        if inSingle {
            return (singleStartCol, "Unclosed single quote (')")
        }
        return nil
    }
    
    private func extractMappingKey(from text: String) -> String? {
        var remainder = text
        if remainder.hasPrefix("- ") {
            remainder = String(remainder.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        
        if let colonIndex = remainder.firstIndex(of: ":") {
            let after = remainder[remainder.index(after: colonIndex)...]
            if after.isEmpty || after.hasPrefix(" ") || after.hasPrefix("\t") {
                let key = String(remainder[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let cleaned = key.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                return cleaned.isEmpty ? nil : cleaned
            }
        }
        return nil
    }
}
