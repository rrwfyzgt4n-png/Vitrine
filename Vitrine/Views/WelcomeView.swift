import SwiftUI

struct WelcomeView: View {
    let isWorking: Bool
    let operationMessage: String?
    let createCatalog: () -> Void
    let openCatalog: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "books.vertical")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Vitrine")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("Browse your physical library using the cover images already stored on your Mac.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            HStack(spacing: 12) {
                Button("Create a Catalog", systemImage: "plus", action: createCatalog)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("welcome.createCatalog")
                Button("Open a Catalog", systemImage: "folder", action: openCatalog)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("welcome.openCatalog")
            }
            .disabled(isWorking)

            if isWorking {
                ProgressView(operationMessage ?? "Working…")
                    .controlSize(.small)
            }
        }
        .padding(48)
    }
}
