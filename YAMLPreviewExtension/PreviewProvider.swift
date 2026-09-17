import Foundation
import QuickLookUI
import UniformTypeIdentifiers

public class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    private let renderer = YAMLHTMLRenderer()
    
    public func providePreview(for request: QLFilePreviewRequest, completionHandler: @escaping (QLPreviewReply?, Error?) -> Void) {
        let fileURL = request.fileURL
        let isAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileName = fileURL.lastPathComponent
        var fileSizeBytes: Int64 = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            fileSizeBytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        }
        
        // Read file contents with fallback encodings
        let content: String
        do {
            content = try readFileContent(from: fileURL)
        } catch {
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <body style="font-family: system-ui; padding: 30px; color: #dc2626;">
                <h2>Unable to read YAML file</h2>
                <p>\(error.localizedDescription)</p>
            </body>
            </html>
            """
            let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 800, height: 600)) { (reply: QLPreviewReply) -> Data in
                return errorHTML.data(using: .utf8) ?? Data()
            }
            completionHandler(reply, nil)
            return
        }
        
        let prefs = YAMLPreferences.shared
        let html = renderer.render(
            yamlString: content,
            fileName: fileName,
            fileSizeBytes: fileSizeBytes,
            preferences: prefs
        )
        
        let contentSize = CGSize(width: 800, height: 600)
        let reply = QLPreviewReply(dataOfContentType: .html, contentSize: contentSize) { (reply: QLPreviewReply) -> Data in
            return html.data(using: .utf8) ?? Data()
        }
        
        completionHandler(reply, nil)
    }
    
    private func readFileContent(from url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }
        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }
        if let ascii = String(data: data, encoding: .ascii) {
            return ascii
        }
        throw NSError(domain: "YAMLPreviewError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported text encoding in YAML file"])
    }
}
