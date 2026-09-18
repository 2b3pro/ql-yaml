import Cocoa
import QuickLookThumbnailing

public class ThumbnailProvider: QLThumbnailProvider {
    public override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let size = request.maximumSize
        let fileURL = request.fileURL
        
        let isAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        var sampleLines: [String] = []
        if let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
           let text = String(data: data.prefix(8192), encoding: .utf8) ?? String(data: data.prefix(8192), encoding: .isoLatin1) {
            sampleLines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        
        let reply = QLThumbnailReply(contextSize: size) { () -> Bool in
            let rect = NSRect(origin: .zero, size: size)
            
            // 1. Fill entire canvas edge-to-edge
            NSColor.white.setFill()
            rect.fill()
            
            // 2. Header Bar
            let headerHeight = max(24.0, min(38.0, size.height * 0.09))
            let headerRect = NSRect(x: 0, y: size.height - headerHeight, width: size.width, height: headerHeight)
            NSColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0).setFill()
            headerRect.fill()
            
            // Header bottom border
            NSColor(red: 0.88, green: 0.90, blue: 0.94, alpha: 1.0).setFill()
            NSRect(x: 0, y: size.height - headerHeight, width: size.width, height: 1.0).fill()
            
            // YAML Badge in header right
            let badgeHeight = max(14.0, headerHeight * 0.65)
            let badgeWidth = badgeHeight * 2.3
            let badgePadding = max(8.0, headerHeight * 0.3)
            let badgeRect = NSRect(
                x: size.width - badgeWidth - badgePadding,
                y: size.height - headerHeight + (headerHeight - badgeHeight) / 2,
                width: badgeWidth,
                height: badgeHeight
            )
            let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight * 0.3, yRadius: badgeHeight * 0.3)
            NSColor(red: 0.10, green: 0.52, blue: 0.95, alpha: 1.0).setFill()
            badgePath.fill()
            
            let badgeText = NSAttributedString(string: "YAML", attributes: [
                .font: NSFont.boldSystemFont(ofSize: max(7, badgeHeight * 0.55)),
                .foregroundColor: NSColor.white
            ])
            let bTextSize = badgeText.size()
            badgeText.draw(at: CGPoint(
                x: badgeRect.midX - bTextSize.width / 2,
                y: badgeRect.midY - bTextSize.height / 2
            ))
            
            // Document Title in header left
            let docTitle = NSAttributedString(string: fileURL.lastPathComponent, attributes: [
                .font: NSFont.systemFont(ofSize: max(8, headerHeight * 0.42), weight: .semibold),
                .foregroundColor: NSColor(white: 0.3, alpha: 1.0)
            ])
            docTitle.draw(at: CGPoint(
                x: max(10, headerHeight * 0.4),
                y: size.height - headerHeight + (headerHeight - docTitle.size().height) / 2
            ))
            
            // 3. Line numbers gutter and content area
            let contentTop = size.height - headerHeight - 8
            let contentBottom: CGFloat = 8
            let availableHeight = contentTop - contentBottom
            
            let gutterWidth = max(26.0, min(42.0, size.width * 0.085))
            let gutterRect = NSRect(x: 0, y: 0, width: gutterWidth, height: size.height - headerHeight)
            NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).setFill()
            gutterRect.fill()
            
            // Gutter right border
            NSColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1.0).setFill()
            NSRect(x: gutterWidth - 1, y: 0, width: 1, height: size.height - headerHeight).fill()
            
            // 4. Determine lines to render and layout
            let linesToRender = sampleLines.isEmpty ? [
                "apiVersion: apps/v1",
                "kind: Deployment",
                "metadata:",
                "  name: application",
                "spec:",
                "  replicas: 3",
                "  template:",
                "    spec:",
                "      containers:",
                "      - name: app",
                "        image: app:latest",
                "        ports:",
                "        - containerPort: 80"
            ] : sampleLines
            
            let minLines = 16
            let maxLines = 32
            let count = max(minLines, min(linesToRender.count, maxLines))
            let lineHeight = availableHeight / CGFloat(count)
            let fontSize = max(7.0, min(12.0, lineHeight * 0.68))
            let codeFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let boldCodeFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
            let gutterFont = NSFont.monospacedSystemFont(ofSize: max(6.5, fontSize * 0.85), weight: .regular)
            
            let contentLeft = gutterWidth + 8
            
            for (i, rawLine) in linesToRender.prefix(count).enumerated() {
                let y = contentTop - CGFloat(i + 1) * lineHeight
                if y < contentBottom { break }
                
                // Draw Line Number
                let lineNumStr = "\(i + 1)"
                let numAttr = NSAttributedString(string: lineNumStr, attributes: [
                    .font: gutterFont,
                    .foregroundColor: NSColor(red: 0.65, green: 0.70, blue: 0.76, alpha: 1.0)
                ])
                let numSize = numAttr.size()
                numAttr.draw(at: CGPoint(x: gutterWidth - numSize.width - 6, y: y + (lineHeight - numSize.height) / 2))
                
                // Draw Syntax-Highlighted Line Content
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                var color = NSColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
                var font = codeFont
                
                if trimmed.hasPrefix("#") {
                    color = NSColor(red: 0.55, green: 0.60, blue: 0.67, alpha: 1.0)
                } else if trimmed.hasPrefix("-") {
                    color = NSColor(red: 0.08, green: 0.55, blue: 0.25, alpha: 1.0)
                    font = boldCodeFont
                } else if rawLine.contains(":") {
                    color = NSColor(red: 0.05, green: 0.45, blue: 0.85, alpha: 1.0)
                    font = boldCodeFont
                }
                
                let lineAttr = NSAttributedString(string: rawLine, attributes: [
                    .font: font,
                    .foregroundColor: color
                ])
                lineAttr.draw(at: CGPoint(x: contentLeft, y: y + (lineHeight - fontSize * 1.1) / 2))
            }
            
            return true
        }
        
        reply.extensionBadge = "YAML"
        handler(reply, nil)
    }
}
