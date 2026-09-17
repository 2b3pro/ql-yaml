import SwiftUI
import AppKit

public struct ContentView: View {
    @ObservedObject var preferences = YAMLPreferences.shared
    @State private var selectedTab = 0
    @State private var currentYAML: String = SampleYAML.samples[0].content
    @State private var currentFileName: String = SampleYAML.samples[0].fileName
    @State private var isExtensionRegistered: Bool? = nil
    @State private var statusMessage: String = ""
    @State private var isDropTargeted: Bool = false
    
    private let renderer = YAMLHTMLRenderer()
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            previewView
                .tabItem {
                    Label("YAML Preview", systemImage: "doc.text.magnifyingglass")
                }
                .tag(0)
            
            devonthinkGuideView
                .tabItem {
                    Label("DEVONthink & Finder", systemImage: "macwindow.on.rectangle")
                }
                .tag(1)
            
            settingsView
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            checkExtensionStatus()
        }
    }
    
    // MARK: - Live Preview Tab
    private var previewView: some View {
        VStack(spacing: 0) {
            // Control Bar
            HStack(spacing: 12) {
                Menu {
                    ForEach(SampleYAML.samples) { sample in
                        Button(sample.title) {
                            currentYAML = sample.content
                            currentFileName = sample.fileName
                        }
                    }
                } label: {
                    Label("Load Sample", systemImage: "list.bullet.rectangle")
                }
                .menuStyle(.borderedButton)
                
                Button(action: openYAMLFileDialog) {
                    Label("Open YAML File...", systemImage: "folder")
                }
                
                Spacer()
                
                Text(currentFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Button(action: restartQuickLook) {
                    Label("Refresh QuickLook", systemImage: "arrow.clockwise")
                }
                .help("Flushes macOS QuickLook daemon caches")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .border(width: 1, edges: [.bottom], color: Color(nsColor: .separatorColor))
            
            // Web Preview
            let html = renderer.render(
                yamlString: currentYAML,
                fileName: currentFileName,
                fileSizeBytes: Int64(currentYAML.utf8.count),
                preferences: preferences
            )
            
            YAMLWebView(htmlString: html)
                .overlay {
                    if isDropTargeted {
                        ZStack {
                            Color.accentColor.opacity(0.15)
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color.accentColor)
                                Text("Drop YAML File Here")
                                    .font(.title2.bold())
                            }
                        }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let fileURL = url else { return }
                        loadFile(at: fileURL)
                    }
                    return true
                }
        }
    }
    
    // MARK: - DEVONthink & Finder Guide Tab
    private var devonthinkGuideView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(isExtensionRegistered == true ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YAML QuickLook Extension Status")
                            .font(.title2.bold())
                        
                        Text(isExtensionRegistered == true ? "Extension is installed and registered with macOS." : "Extension registered. Ensure it is toggled ON in System Settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Check Status") {
                        checkExtensionStatus()
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // DEVONthink Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        Text("Using with DEVONthink")
                            .font(.title3.bold())
                    }
                    
                    Text("DEVONthink natively uses macOS QuickLook (QLPreviewView) to render previews for files it does not natively edit. Once this extension is active:")
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        GuideStepRow(
                            number: "1",
                            title: "Preview in DEVONthink Pane",
                            description: "Select any .yaml or .yml file in your DEVONthink database. The Preview / Inspector pane immediately renders the syntax-highlighted document."
                        )
                        GuideStepRow(
                            number: "2",
                            title: "Full Spacebar Quick Look",
                            description: "Press the Spacebar on any YAML document in DEVONthink to open the full interactive QuickLook window with code folding, copy button, and diagnostics."
                        )
                        GuideStepRow(
                            number: "3",
                            title: "Appearance Auto-Sync",
                            description: "When DEVONthink switches between Dark and Light mode, the YAML preview automatically matches DEVONthink's theme."
                        )
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: openDEVONthink) {
                            Label("Launch DEVONthink", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: openExtensionsSettings) {
                            Label("Open Quick Look Settings...", systemImage: "gearshape")
                        }
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Finder Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .font(.title3)
                            .foregroundStyle(.indigo)
                        Text("Using in Finder")
                            .font(.title3.bold())
                    }
                    
                    Text("Select any .yaml or .yml file in Finder and press **Spacebar** or enable Finder Column Preview. You get full syntax highlighting, collapsible code sections, and line numbers.")
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        Button(action: restartQuickLook) {
                            Label("Flush QuickLook Caches", systemImage: "arrow.clockwise")
                        }
                        
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
        }
    }
    
    // MARK: - Settings Tab
    private var settingsView: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $preferences.theme) {
                    ForEach(YAMLTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                
                Stepper("Font Size: \(preferences.fontSize) pt", value: $preferences.fontSize, in: 10...22)
            }
            
            Section("Features & Wrapping") {
                Toggle("Soft Wrap in Raw Mode", isOn: $preferences.softWrapRaw)
                Toggle("Soft Wrap in Highlighted View", isOn: $preferences.softWrapCode)
                Toggle("Show Line Numbers", isOn: $preferences.showLineNumbers)
                Toggle("Enable Code Folding", isOn: $preferences.enableFolding)
                Toggle("Show Indent Guides", isOn: $preferences.showIndentGuides)
                Toggle("Show Metadata Header Bar", isOn: $preferences.showHeader)
            }
            
            Section {
                Button("Reset Preferences to Defaults") {
                    preferences.theme = .system
                    preferences.fontSize = 13
                    preferences.softWrapRaw = true
                    preferences.softWrapCode = false
                    preferences.showLineNumbers = true
                    preferences.enableFolding = true
                    preferences.showIndentGuides = true
                    preferences.showHeader = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Actions
    private func openYAMLFileDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.yaml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            loadFile(at: url)
        }
    }
    
    private func loadFile(at url: URL) {
        if let data = try? Data(contentsOf: url),
           let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            DispatchQueue.main.async {
                self.currentYAML = str
                self.currentFileName = url.lastPathComponent
            }
        }
    }
    
    private func checkExtensionStatus() {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            task.arguments = ["-m", "-p", "com.apple.quicklook.preview"]
            let pipe = Pipe()
            task.standardOutput = pipe
            
            try? task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let isRegistered = output.contains("qlyaml") || output.contains("YAMLPreview")
            
            DispatchQueue.main.async {
                self.isExtensionRegistered = isRegistered
            }
        }
    }
    
    private func openExtensionsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openDEVONthink() {
        let devonthinkURL = URL(fileURLWithPath: "/Applications/DEVONthink.app")
        NSWorkspace.shared.openApplication(at: devonthinkURL, configuration: .init(), completionHandler: nil)
    }
    
    private func restartQuickLook() {
        DispatchQueue.global(qos: .userInitiated).async {
            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            p1.arguments = ["-r"]
            try? p1.run()
            p1.waitUntilExit()
            
            let p2 = Process()
            p2.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
            p2.arguments = ["-r", "cache"]
            try? p2.run()
            p2.waitUntilExit()
            
            DispatchQueue.main.async {
                self.statusMessage = "QuickLook daemon cache flushed successfully!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.statusMessage = ""
                }
            }
        }
    }
}

private struct GuideStepRow: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 26, height: 26)
                Text(number)
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// Edge border helper
private extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

private struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }
            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }
            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }
            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}
