import SwiftUI

@main
struct HotpotSaveEditorApp: App {
    @StateObject private var editor = SaveEditorModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(editor)
        }
    }
}
