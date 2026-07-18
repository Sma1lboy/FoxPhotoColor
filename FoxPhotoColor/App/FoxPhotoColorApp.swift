import SwiftUI

@main
struct FoxPhotoColorApp: App {
    @StateObject private var store = CardStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .task {
                    SampleSeed.seedIfNeeded(into: store)
                }
        }
    }
}
