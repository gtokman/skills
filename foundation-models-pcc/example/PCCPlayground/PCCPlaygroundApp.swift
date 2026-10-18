import SwiftUI

@main
struct PCCPlaygroundApp: App {
    @State private var store = ModelStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Playground", systemImage: "sparkles") { PlaygroundView() }
                Tab("Compare", systemImage: "square.split.2x1") { CompareView() }
                Tab("Status", systemImage: "gauge.with.dots.needle.50percent") { StatusView() }
            }
            .environment(store)
            .task { await store.loadPCCContextSize() }
        }
    }
}
