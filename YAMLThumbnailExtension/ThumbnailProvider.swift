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
           let text = String(data: data.prefix(4096), encoding: .utf8) {
            sampleLines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        
        let reply = QLThumbnailReply(contextSize: size) { (context: CGContext) -> Bool in
            let rect = CGRect(origin: .zero, size: size)
            
            // Draw page background
            let padding: CGFloat = size.width * 0.08
            let pageRect = rect.insetBy(dx: padding, dy: padding)
            let cornerRadius: CGFloat = max(4, pageRect.width * 0.06)
            
            context.saveGState()
            
            // Subtle document drop shadow
            context.setShadow(offset: CGSize(width: 0, height: -pageRect.height * 0.03), blur: pageRect.width * 0.08, color: NSColor.black.withAlphaComponent(0.2).cgColor)
            
            // White document card
            let path = CGPath(roundedRect: pageRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.setFillColor(NSColor.white.cgColor)
            context.addPath(path)
            context.fillPath()
            
            context.restoreGState()
            
            // Border
            context.saveGState()
            context.addPath(path)
            context.setStrokeColor(NSColor(white: 0.85, alpha: 1.0).cgColor)
            context.setLineWidth(max(1, size.width * 0.005))
            context.strokePath()
            context.restoreGState()
            
            // Top Bar with YAML Badge
            let topBarHeight: CGFloat = pageRect.height * 0.16
            let badgeRect = CGRect(
                x: pageRect.maxX - pageRect.width * 0.35,
                y: pageRect.maxY - topBarHeight * 0.85,
                width: pageRect.width * 0.28,
                height: topBarHeight * 0.65
            )
            let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: badgeRect.height * 0.3, cornerHeight: badgeRect.height * 0.3, transform: nil)
            context.setFillColor(NSColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 1.0).cgColor)
            context.addPath(badgePath)
            context.fillPath()
            
            // Draw "YAML" text in badge
            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: max(8, badgeRect.height * 0.55)),
                .foregroundColor: NSColor.white
            ]
            let badgeText = NSAttributedString(string: "YAML", attributes: badgeAttrs)
            let textSize = badgeText.size()
            let textPoint = CGPoint(
                x: badgeRect.midX - textSize.width / 2,
                y: badgeRect.midY - textSize.height / 2
            )
            
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = nsContext
            badgeText.draw(at: textPoint)
            
            // Draw Code Lines
            let contentTop = pageRect.maxY - topBarHeight - pageRect.height * 0.05
            let contentLeft = pageRect.minX + pageRect.width * 0.08
            let contentWidth = pageRect.width * 0.84
            let contentBottom = pageRect.minY + pageRect.height * 0.08
            let availableHeight = contentTop - contentBottom
            
            let numLines = min(sampleLines.count > 0 ? sampleLines.count : 10, 14)
            let lineSpacing = availableHeight / CGFloat(max(numLines, 8))
            
            if size.width >= 160 && !sampleLines.isEmpty {
                // Render real miniature text lines
                let codeFont = NSFont.monospacedSystemFont(ofSize: max(7, lineSpacing * 0.65), weight: .regular)
                for (i, rawLine) in sampleLines.prefix(numLines).enumerated() {
                    let y = contentTop - CGFloat(i + 1) * lineSpacing
                    let lineStr = String(rawLine.prefix(40))
                    
                    var color = NSColor(white: 0.2, alpha: 1.0)
                    if lineStr.contains(":") {
                        color = NSColor(red: 0.05, green: 0.45, blue: 0.8, alpha: 1.0)
                    } else if lineStr.hasPrefix("-") {
                        color = NSColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1.0)
                    } else if lineStr.hasPrefix("#") {
                        color = NSColor(white: 0.6, alpha: 1.0)
                    }
                    
                    let attrStr = NSAttributedString(string: lineStr, attributes: [
                        .font: codeFont,
                        .foregroundColor: color
                    ])
                    attrStr.draw(at: CGPoint(x: contentLeft, y: y))
                }
            } else {
                // Render stylized colored placeholder bars
                for i in 0..<numLines {
                    let y = contentTop - CGFloat(i + 1) * lineSpacing
                    let indent = (i % 3 == 0) ? 0 : (i % 3 == 1 ? pageRect.width * 0.08 : pageRect.width * 0.16)
                    let barWidth = max(contentWidth * 0.3, contentWidth * (0.85 - CGFloat(i % 4) * 0.12) - indent)
                    let barRect = CGRect(x: contentLeft + indent, y: y, width: barWidth, height: max(2, lineSpacing * 0.4))
                    
                    let barColor: CGColor
                    if i % 3 == 0 {
                        barColor = NSColor(red: 0.1, green: 0.5, blue: 0.85, alpha: 0.8).cgColor
                    } else if i % 3 == 1 {
                        barColor = NSColor(red: 0.15, green: 0.65, blue: 0.35, alpha: 0.7).cgColor
                    } else {
                        barColor = NSColor(red: 0.9, green: 0.4, blue: 0.2, alpha: 0.7).cgColor
                    }
                    
                    context.setFillColor(barColor)
                    context.fill(barRect)
                }
            }
            
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        
        handler(reply, nil)
    }
}
