import SwiftUI

struct SettingsView: View {
    @AppStorage("coverWidth") private var coverWidth = 168.0
    @AppStorage("showFileNoteSummaries") private var showFileNoteSummaries = true
    @AppStorage("fallbackSearchEngine") private var fallbackSearchEngine = WebSearchEngine.duckDuckGo.rawValue
    @AppStorage("metadataLanguage") private var metadataLanguage = "auto"

    var body: some View {
        Form {
            Slider(value: $coverWidth, in: 120...260, step: 4) {
                Text("Cover size")
            }
            Toggle("Show File Notes below covers", isOn: $showFileNoteSummaries)
            Picker("Browser search", selection: $fallbackSearchEngine) {
                ForEach(WebSearchEngine.allCases) { Text($0.label).tag($0.rawValue) }
            }
            Picker("Metadata language", selection: $metadataLanguage) {
                Text("Automatic").tag("auto")
                Text("French").tag("fr")
                Text("English").tag("en")
            }
            Text("Vitrine only contacts Open Library when you explicitly start a search.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 330)
    }
}
