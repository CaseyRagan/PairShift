import SwiftUI

@main
struct PairShiftApp: App {
    @StateObject private var store: GameStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PairShiftUITests/progress.json")
            if arguments.contains("-reset-progress") { try? FileManager.default.removeItem(at: url) }
            _store = StateObject(wrappedValue: GameStore(saveURL: url))
        } else {
            _store = StateObject(wrappedValue: GameStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            GameView(store: store)
                .preferredColorScheme(store.settings.appearance == .system ? nil : (store.settings.appearance == .dark ? .dark : .light))
                .onChange(of: scenePhase) { _, phase in
                    // Scene transitions can briefly be .inactive while the
                    // window is still visible (calls, interruptions, tests).
                    // Save/cancel delayed cues on background, while keeping a
                    // foreground board responsive during that transition.
                    store.setActive(phase != .background)
                }
        }
    }
}
