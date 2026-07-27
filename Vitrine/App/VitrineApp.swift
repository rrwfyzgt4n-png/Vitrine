import SwiftUI

@main
@MainActor
struct VitrineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = CatalogStore()

    var body: some Scene {
        Window("Vitrine", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    appDelegate.configureTermination {
                        try await store.flushPendingSaves()
                    }
                }
        }
        .defaultSize(width: 1280, height: 820)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.automatic)
        .commands {
            AppCommands(store: store)
        }

        Window("About Vitrine", id: "about") {
            AboutVitrineView(store: store)
        }
        .defaultSize(width: 620, height: 690)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
        }
    }
}
